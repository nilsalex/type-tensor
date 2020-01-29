{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleContexts #-}

module DiffeoSymmetry where

import TH
import Tensor
import Scalar
import Area
import Sym2
import Delta

import Control.Monad.Except
import Data.Ratio
import Data.List (sort,nub)
import Data.List.NonEmpty (NonEmpty(..))


--
--  L_A^p * C^A_B_p^{qm}_n * v^B_q
--
someInterAreaJet1 :: (Num v, MonadError String m) =>
                     Label ->
                     Label -> Label ->
                     Label -> Label ->
                     Label -> Label ->
                     m (T v)
someInterAreaJet1 id m n a b p q = do
    i1 <- c .* someDelta id 4 q p
    i2 <- (someDeltaArea id a b .* ) =<< (someDelta id 4 m p .* someDelta id 4 q n)
    res :: T Int <- i1 .+ i2
    return $ fmap fromIntegral res
  where
    c = someInterAreaCon id m n a b

--
--  L_A^I * C^A_B_I^{Jm}_n * v^B_J
--
someInterAreaJet2 :: Num v =>
                     Label ->
                     Label -> Label ->
                     Label -> Label ->
                     Label -> Label ->
                     T v
someInterAreaJet2 id m n a b i j = int
  where
    c = someInterAreaCon id m n a b
    k = someInterSym2Cov id 4 m n i j
    Right int = runExcept $
      do
        i1 <- c .* someDeltaSym2 id 4 j i
        i2 <- k .* someDeltaArea id a b
        res :: T Int <- i1 .+ i2
        return $ fmap fromIntegral res

--
--  L_A^r * C^A_B_r^{pm}_n * v^B
--
someInterAreaJet1_2 :: (Num v, MonadError String m) =>
                       Label ->
                       Label -> Label ->
                       Label -> Label ->
                       Label -> Label ->
                       m (T v)
someInterAreaJet1_2 id m n a b r p = do
    i <- c .* someDelta id 4 p r
    i' <- (i .+) =<< transposeT (VSpace id 4) (ICon m) (ICon p) i
    return $ fmap fromIntegral i'
  where
    c = someInterAreaCon id m n a b

--
--  L_A^I * C^A_B_I^{qpm}_n * v^B_q
--
someInterAreaJet2_2 :: (Num v, MonadError String m) =>
                       Label ->
                       Label -> Label ->
                       Label -> Label ->
                       Label ->
                       Label -> Label ->
                       m (T v)
someInterAreaJet2_2 id m n a b i q p = do
    i1 <- (c .*) =<< someSurjSym2Cov id 4 p q i
    i2 <- (dA .*) =<< ((dST .*) =<< someSurjSym2Cov id 4 p m i)
    i1' <- (i1 .+) =<< transposeT (VSpace id 4) (ICon m) (ICon p) i1
    fmap (fmap (\v -> let v' = 2*v in
                      if denominator v' == 1
                      then fromIntegral (numerator v')
                      else error "")) $ i1' .+ i2
  where
    c :: T Rational = someInterAreaCon id m n a b
    dA = someDeltaArea id a b
    dST = someDelta id 4 q n

--
--  L_A^I * C^A_B_I^{pqm}_n * v^B
--
someInterAreaJet2_3 :: (Num v, MonadError String m) =>
                       Label ->
                       Label -> Label ->
                       Label -> Label ->
                       Label ->
                       Label -> Label ->
                       m (T v)
someInterAreaJet2_3 id m n a b i p q = do
    j <- someSurjSym2Cov id 4 p q i
    t1 <- c .* j
    t2 <- transposeMultT (VSpace id 4) [(m,m),(p,q),(q,p)] [] t1
    t3 <- transposeMultT (VSpace id 4) [(m,p),(p,m),(q,q)] [] t1
    t4 <- transposeMultT (VSpace id 4) [(m,p),(p,q),(q,m)] [] t1
    t5 <- transposeMultT (VSpace id 4) [(m,q),(p,m),(q,p)] [] t1
    t6 <- transposeMultT (VSpace id 4) [(m,q),(p,p),(q,m)] [] t1
    res <- (t6 .+) =<< (t5 .+) =<< (t4 .+) =<< (t3 .+) =<< (t2 .+ t1)
    return $ fmap (\v -> if denominator v == 1
                         then fromIntegral (numerator v)
                         else error "") res
  where
    c :: T Rational = someInterAreaCon id m n a b

diffeoEq1 :: (Num v, Eq v, MonadError String m) =>
             T v -> m (T v)
diffeoEq1 ansatz4 = do
    res <- fmap contractT $ (ansatz4 .*) =<< (c .* n)
    case rankT res of
      [(VSpace "ST" 4, ConCov ("m" :| []) ("n" :| []))] -> return res
      _ -> throwError $ "diffeoEq1: inconsistent ansatz rank\n" ++ show (rankT ansatz4)
  where
    n = someFlatAreaCon "ST" "B"
    c = someInterAreaCon "ST" "m" "n" "A" "B"

diffeoEq3 :: (Num v, Eq v, MonadError String m) =>
             T v -> m (T v)
diffeoEq3 ansatz6 = do
    c   <- someInterAreaJet2_3 "ST" "m" "n" "A" "B" "I" "p" "q"
    res <- fmap contractT $ (ansatz6 .*) =<< (c .* n)
    case rankT res of
      [(VSpace "ST" 4, ConCov ("m" :| ["p","q"]) ("n" :| []))] -> return res
      _ -> throwError $ "diffeoEq3: inconsistent ansatz rank\n" ++ show (rankT ansatz6)
  where
    n = someFlatAreaCon "ST" "B"

diffeoEq1A :: (Num v, Eq v, MonadError String m) =>
              T v -> T v -> m (T v)
diffeoEq1A ansatz4 ansatz8 = do
    e1 <- fmap contractT $ (.* c1) =<< (relabelT (VSpace "STArea" 21) [("A","B")] ansatz4)
    e2 <- (two .*) =<< fmap contractT ((ansatz8 .*) =<< (c2 .* n))
    res <- e1 .+ e2
    case rankT res of
      [(VSpace "ST" 4, ConCov ("m" :| []) ("n" :| [])),
       (VSpace "STArea" 21, Cov ("A" :| []))] -> return res
      _ -> throwError $ "diffeoEq1A: inconsistent ansatz ranks\n" ++
                        show (rankT ansatz4) ++ "\n" ++
                        show (rankT ansatz8)
  where
    n = someFlatAreaCon "ST" "C"
    c1 = someInterAreaCon "ST" "m" "n" "B" "A"
    c2 = someInterAreaCon "ST" "m" "n" "B" "C"
    two = scalar 2

diffeoEq1AI :: (Num v, Eq v, MonadError String m) =>
               T v -> T v -> m (T v)
diffeoEq1AI ansatz6 ansatz10_1 = do
    ansatz10_1' <- relabelT (VSpace "STArea" 21) [("A","B"),("B","A")] ansatz10_1
    ansatz6' <- relabelT (VSpace "STArea" 21) [("A","B")] =<<
                relabelT (VSpace "STSym2" 10) [("I","J")] ansatz6
    e1 <- fmap contractT $ (ansatz10_1' .*) =<< (c1 .* n)
    e2 <- fmap contractT $ ansatz6' .* c2
    res <- e1 .+ e2
    case rankT res of
      [(VSpace "ST" 4, ConCov ("m" :| []) ("n" :| [])),
       (VSpace "STArea" 21, Cov ("A" :| [])),
       (VSpace "STSym2" 10, Con ("I" :| []))] -> return res
      _ -> throwError $ "diffeoEq1AI: inconsistent ansatz ranks\n" ++
                        show (rankT ansatz6) ++ "\n" ++
                        show (rankT ansatz10_1)
  where
    n = someFlatAreaCon "ST" "C"
    c1 = someInterAreaCon "ST" "m" "n" "B" "C"
    c2 = someInterAreaJet2 "ST" "m" "n" "B" "A" "J" "I"

diffeoEq2Ap :: (Num v, Eq v, MonadError String m) =>
               T v -> T v -> m (T v)
diffeoEq2Ap ansatz6 ansatz10_2 = do
    c1 <- someInterAreaJet1_2 "ST" "m" "n" "B" "C" "r" "q"
    c2 <- someInterAreaJet2_2 "ST" "m" "n" "B" "A" "I" "p" "q"
    ansatz6' <- relabelT (VSpace "STArea" 21) [("A","B")] ansatz6
    ansatz10_2' <- relabelT (VSpace "ST" 4) [("q","r")] ansatz10_2
    e1 <- (two .*) =<< fmap contractT ((ansatz10_2' .*) =<< (c1 .* n))
    e2 <- fmap contractT $ ansatz6' .* c2
    res <- e1 .+ e2
    case rankT res of
      [(VSpace "ST" 4, ConCov ("m" :| ["p","q"]) ("n" :| [])),
       (VSpace "STArea" 21, Cov ("A" :| []))] -> return res
      _ -> throwError $ "diffeoEq2Ap: inconsistent ansatz ranks\n" ++
                        show (rankT ansatz6) ++ "\n" ++
                        show (rankT ansatz10_2)
  where
    n = someFlatAreaCon "ST" "C"
    two = scalar 2

diffeoEq3A :: (Num v, Eq v, MonadError String m) =>
              T v -> T v -> m (T v)
diffeoEq3A ansatz6 ansatz10_1 = do
    c1 <- someInterAreaJet2_3 "ST" "m" "n" "B" "C" "I" "p" "q"
    c2 <- someInterAreaJet2_3 "ST" "m" "n" "B" "A" "I" "p" "q"
    ansatz6' <- relabelT (VSpace "STArea" 21) [("A","B")] ansatz6
    e1 <- fmap contractT $ (ansatz10_1 .*) =<< (c1 .* n)
    e2 <- fmap contractT $ ansatz6' .* c2
    res <- e1 .+ e2
    case rankT res of
      [(VSpace "ST" 4, ConCov ("m" :| ["p","q"]) ("n" :| [])),
       (VSpace "STArea" 21, Cov ("A" :| []))] -> return res
      _ -> throwError $ "diffeoEq2Ap: inconsistent ansatz ranks\n" ++
                        show (rankT ansatz6) ++ "\n" ++
                        show (rankT ansatz10_1)
  where
    n = someFlatAreaCon "ST" "C"

sndOrderDiffeoEqns :: (Num v, Eq v, MonadError String m) =>
                      [T v] -> m ([T v])
sndOrderDiffeoEqns [ans4,ans6,ans8,ans10_1,ans10_2] =
  sequence $ [
              diffeoEq1 ans4,
              diffeoEq3 ans6,
              diffeoEq1A ans4 ans8,
              diffeoEq1AI ans6 ans10_1,
              diffeoEq2Ap ans6 ans10_2,
              diffeoEq3A ans6 ans10_1
             ]
sndOrderDiffeoEqns as = throwError $ "wrong number of ansatz tensors : " ++ show (length as)

tensorToEquations :: T (Poly Rational) -> [Poly Rational]
tensorToEquations = nub . sort . fmap (normalize . snd) . toListT
