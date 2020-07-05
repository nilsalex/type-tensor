{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE NoStarIsType #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE OverloadedStrings #-}

module Sym2 where

import TH
import Safe
import Tensor
import Delta

import Data.Singletons
import Data.Singletons.Prelude
import Data.Singletons.Decide
import Data.Singletons.TypeLits

import Data.Ratio
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.Map.Strict as Map

import Control.Monad.Except

trianMapSym2 :: Integral a => a -> Map.Map (Vec (S (S Z)) Int) Int
trianMapSym2 n = Map.fromList $ zip indices2 indices1
  where
    maxInd   = fromIntegral n - 1
    indices1 = [0..]
    indices2 = [a `VCons` (b `VCons` VNil) | a <- [0..maxInd], b <- [a..maxInd] ]

facMapSym2 :: (Integral a, Num b) => a -> Map.Map (Vec (S (S Z)) Int) b
facMapSym2 n = Map.fromList $ [(a `VCons` (b `VCons` VNil), fac a b) |
                                  a <- [0..maxInd], b <- [a..maxInd] ]
  where
    maxInd = fromIntegral n - 1
    fac a b
      | a == b    = 1
      | otherwise = 2

sym2Assocs :: forall (n :: Nat) v.Num v => Sing n -> [(Vec (S (S (S Z))) Int, v)]
sym2Assocs sn = assocs
  where
    n  = withKnownNat sn (natVal sn)
    tm = trianMapSym2 n
    maxInd = fromIntegral n - (1 :: Int)
    assocs = (\a b -> let v = vec a b
                      in case Map.lookup v tm of
                           Just i -> (a `VCons` (b `VCons` (i `VCons` VNil)), 1 :: v)
                           _      -> error $ "indices " ++ show (min a b, max a b) ++
                                             " not present in triangle map " ++ show tm)
             <$> [0..maxInd] <*> [0..maxInd]

    vec a b = min a b `VCons` (max a b `VCons` VNil)

sym2AssocsFac :: forall (n :: Nat) v.Fractional v => Sing n -> [(Vec (S (S (S Z))) Int, v)]
sym2AssocsFac sn = assocs
  where
    n  = withKnownNat sn (natVal sn)
    tm = trianMapSym2 n
    fm = facMapSym2 n
    maxInd = fromIntegral (withKnownNat sn (natVal sn)) - (1 :: Int)
    assocs = (\a b -> case
                        (do
                           let v = vec a b
                           i <- Map.lookup v tm
                           f <- Map.lookup v fm
                           return (a `VCons` (b `VCons` (i `VCons` VNil)), 1 / f :: v)) of
                        Just x -> x
                        Nothing -> error "sym2AssocsFac are not fraction-free, as they should be!")
             <$> [0..maxInd] <*> [0..maxInd]

    vec a b = min a b `VCons` (max a b `VCons` VNil)

gamma' :: forall (id :: Symbol) (n :: Nat) (a :: Symbol) (b :: Symbol) (l :: ILists) v.
           (
            '[ '( 'VSpace id n, 'Cov (a :| '[b])) ] ~ l,
            (a < b) ~ 'True,
            SingI n,
            Num v
           ) =>
           Sing id -> Sing n -> Sing a -> Sing b ->
           Tensor l v
gamma' _ _ _ _ = gamma

gamma :: forall (id :: Symbol) (n :: Nat) (a :: Symbol) (b :: Symbol) (l :: ILists) v.
         (
          '[ '( 'VSpace id n, 'Cov (a :| '[b])) ] ~ l,
          (a < b) ~ 'True,
          SingI n,
          Num v
         ) => Tensor l v
gamma = case (sing :: Sing n) of
          sn -> let x = fromIntegral $ withKnownNat sn $ natVal sn
                in Tensor (f x)
  where
    f x = map (\i -> (i, Tensor [(i, Scalar 1)])) [0..x - 1]

eta' :: forall (id :: Symbol) (n :: Nat) (a :: Symbol) (b :: Symbol) (l :: ILists) v.
        (
         '[ '( 'VSpace id n, 'Cov (a :| '[b])) ] ~ l,
         (a < b) ~ 'True,
         SingI n,
         Num v
        ) =>
        Sing id -> Sing n -> Sing a -> Sing b ->
        Tensor l v
eta' _ _ _ _ = eta

eta :: forall (id :: Symbol) (n :: Nat) (a :: Symbol) (b :: Symbol) (l :: ILists) v.
       (
        '[ '( 'VSpace id n, 'Cov (a :| '[b])) ] ~ l,
        (a < b) ~ 'True,
        SingI n,
        Num v
       ) => Tensor l v
eta = case (sing :: Sing n) of
        sn -> let x = fromIntegral $ withKnownNat sn $ natVal sn
              in Tensor (f x)
  where
    f x = map (\i -> (i, Tensor [(i, Scalar (if i == 0 then 1 else -1))])) [0..x - 1]

gammaInv' :: forall (id :: Symbol) (n :: Nat) (a :: Symbol) (b :: Symbol) (l :: ILists) v.
          (
           '[ '( 'VSpace id n, 'Con (a :| '[b])) ] ~ l,
           (a < b) ~ 'True,
           SingI n,
           Num v
          ) =>
          Sing id -> Sing n -> Sing a -> Sing b ->
          Tensor l v
gammaInv' _ _ _ _ = gammaInv

gammaInv :: forall (id :: Symbol) (n :: Nat) (a :: Symbol) (b :: Symbol) (l :: ILists) v.
          (
           '[ '( 'VSpace id n, 'Con (a :| '[b])) ] ~ l,
           (a < b) ~ 'True,
           SingI n,
           Num v
          ) => Tensor l v
gammaInv = case (sing :: Sing n) of
            sn -> let x = fromIntegral $ withKnownNat sn $ natVal sn
                  in Tensor (f x)
  where
    f x = map (\i -> (i, Tensor [(i, Scalar 1)])) [0..x - 1]

etaInv' :: forall (id :: Symbol) (n :: Nat) (a :: Symbol) (b :: Symbol) (l :: ILists) v.
        (
         '[ '( 'VSpace id n, 'Con (a :| '[b])) ] ~ l,
         (a < b) ~ 'True,
         SingI n,
         Num v
        ) =>
        Sing id -> Sing n -> Sing a -> Sing b ->
        Tensor l v
etaInv' _ _ _ _ = etaInv

etaInv :: forall (id :: Symbol) (n :: Nat) (a :: Symbol) (b :: Symbol) (l :: ILists) v.
       (
        '[ '( 'VSpace id n, 'Con (a :| '[b])) ] ~ l,
        (a < b) ~ 'True,
        SingI n,
        Num v
       ) => Tensor l v
etaInv = case (sing :: Sing n) of
        sn -> let x = fromIntegral $ withKnownNat sn $ natVal sn
              in Tensor (f x)
  where
    f x = map (\i -> (i, Tensor [(i, Scalar (if i == 0 then 1 else -1))])) [0..x - 1]

injSym2Con' :: forall (id :: Symbol) (n :: Nat) (a :: Symbol) (b :: Symbol)
                      (i :: Symbol) (l :: ILists) v.
               (
                InjSym2ConILists id n a b i ~ 'Just l,
                SingI l,
                Num v
               ) => Sing id -> Sing n -> Sing a -> Sing b -> Sing i -> Tensor l v
injSym2Con' svid svdim sa sb si =
        case sSane sl %~ STrue of
          Proved Refl ->
            case sLengthILs sl of
              SS (SS (SS SZ)) -> fromList $ sym2Assocs svdim
  where
    sl = sing :: Sing l

injSym2Cov' :: forall (id :: Symbol) (n :: Nat) (a :: Symbol) (b :: Symbol)
                      (i :: Symbol) (l :: ILists) v.
               (
                InjSym2CovILists id n a b i ~ 'Just l,
                SingI l,
                Num v
               ) => Sing id -> Sing n -> Sing a -> Sing b -> Sing i -> Tensor l v
injSym2Cov' svid svdim sa sb si =
        case sSane sl %~ STrue of
          Proved Refl ->
            case sLengthILs sl of
              SS (SS (SS SZ)) -> fromList $ sym2Assocs svdim
  where
    sl = sing :: Sing l

surjSym2Con' :: forall (id :: Symbol) (n :: Nat) (a :: Symbol) (b :: Symbol)
                      (i :: Symbol) (l :: ILists) v.
               (
                SurjSym2ConILists id n a b i ~ 'Just l,
                SingI l,
                Fractional v
               ) => Sing id -> Sing n -> Sing a -> Sing b -> Sing i -> Tensor l v
surjSym2Con' svid svdim sa sb si =
        case sSane sl %~ STrue of
          Proved Refl ->
            case sLengthILs sl of
              SS (SS (SS SZ)) -> fromList $ sym2AssocsFac svdim
  where
    sl = sing :: Sing l

surjSym2Cov' :: forall (id :: Symbol) (n :: Nat) (a :: Symbol) (b :: Symbol)
                      (i :: Symbol) (l :: ILists) v.
               (
                SurjSym2CovILists id n a b i ~ 'Just l,
                SingI l,
                Fractional v
               ) => Sing id -> Sing n -> Sing a -> Sing b -> Sing i -> Tensor l v
surjSym2Cov' svid svdim sa sb si =
        case sSane sl %~ STrue of
          Proved Refl ->
            case sLengthILs sl of
              SS (SS (SS SZ)) -> fromList $ sym2AssocsFac svdim
  where
    sl = sing :: Sing l

someGamma :: (Num v, MonadError String m) =>
             Demote Symbol -> Demote Nat -> Demote Symbol -> Demote Symbol ->
             m (T v)
someGamma vid vdim a b
    | a > b = someGamma vid vdim b a
    | a == b = throwError $ "cannot construct gamma with indices " ++ show vid ++ " " ++ show vdim ++ " " ++ show a ++ " " ++ show b
    | otherwise =
        withSomeSing vid $ \svid ->
        withSomeSing vdim $ \svdim ->
        withSomeSing a $ \sa ->
        withSomeSing b $ \sb ->
        withKnownNat svdim $
        withKnownSymbol svid $
        withKnownSymbol sa $
        withKnownSymbol sb $
        case sCompare sa sb of
          SLT -> return $ T $ gamma' svid svdim sa sb

someGammaInv :: (Num v, MonadError String m) =>
                Demote Symbol -> Demote Nat -> Demote Symbol -> Demote Symbol ->
                m (T v)
someGammaInv vid vdim a b
    | a > b = someGammaInv vid vdim b a
    | a == b = throwError $ "cannot construct gamma with indices " ++ show vid ++ " " ++ show vdim ++ " " ++ show a ++ " " ++ show b
    | otherwise =
        withSomeSing vid $ \svid ->
        withSomeSing vdim $ \svdim ->
        withSomeSing a $ \sa ->
        withSomeSing b $ \sb ->
        withKnownNat svdim $
        withKnownSymbol svid $
        withKnownSymbol sa $
        withKnownSymbol sb $
        case sCompare sa sb of
          SLT -> return $ T $ gammaInv' svid svdim sa sb

someEta :: (Num v, MonadError String m) =>
           Demote Symbol -> Demote Nat -> Demote Symbol -> Demote Symbol ->
           m (T v)
someEta vid vdim a b
    | a > b = someEta vid vdim b a
    | a == b = throwError $ "cannot construct eta with indices " ++ show vid ++ " " ++ show vdim ++ " " ++ show a ++ " " ++ show b
    | otherwise =
        withSomeSing vid $ \svid ->
        withSomeSing vdim $ \svdim ->
        withSomeSing a $ \sa ->
        withSomeSing b $ \sb ->
        withKnownNat svdim $
        withKnownSymbol svid $
        withKnownSymbol sa $
        withKnownSymbol sb $
        case sCompare sa sb of
          SLT -> return $ T $ eta' svid svdim sa sb

someEtaInv :: (Num v, MonadError String m) =>
           Demote Symbol -> Demote Nat -> Demote Symbol -> Demote Symbol ->
           m (T v)
someEtaInv vid vdim a b
    | a > b = someEtaInv vid vdim b a
    | a == b = throwError $ "cannot construct eta with indices " ++ show vid ++ " " ++ show vdim ++ " " ++ show a ++ " " ++ show b
    | otherwise =
        withSomeSing vid $ \svid ->
        withSomeSing vdim $ \svdim ->
        withSomeSing a $ \sa ->
        withSomeSing b $ \sb ->
        withKnownNat svdim $
        withKnownSymbol svid $
        withKnownSymbol sa $
        withKnownSymbol sb $
        case sCompare sa sb of
          SLT -> return $ T $ etaInv' svid svdim sa sb

someInjSym2Con :: (Num v, MonadError String m) =>
                  Demote Symbol -> Demote Nat -> Demote Symbol -> Demote Symbol -> Demote Symbol ->
                  m (T v)
someInjSym2Con vid dim a b i
    | a > b = someInjSym2Con vid dim b a i
    | a == b = throwError $ "Invalid spacetime index for sym2 intertwiner: " ++ show a ++ " " ++ show b ++ "!"
    | otherwise =
        withSomeSing vid $ \svid ->
        withSomeSing dim $ \sdim ->
        withSomeSing a   $ \sa ->
        withSomeSing b   $ \sb ->
        withSomeSing i   $ \si ->
        case sInjSym2ConILists svid sdim sa sb si of
          SJust sl ->
            withSingI sl $
            case sSane sl %~ STrue of
              Proved Refl -> return $ T $ injSym2Con' svid sdim sa sb si

someInjSym2Cov :: (Num v, MonadError String m) =>
                  Demote Symbol -> Demote Nat -> Demote Symbol -> Demote Symbol -> Demote Symbol ->
                  m (T v)
someInjSym2Cov vid dim a b i
    | a > b = someInjSym2Cov vid dim b a i
    | a == b = throwError $ "Invalid spacetime index for sym2 intertwiner: " ++ show a ++ " " ++ show b ++ "!"
    | otherwise =
        withSomeSing vid $ \svid ->
        withSomeSing dim $ \sdim ->
        withSomeSing a   $ \sa ->
        withSomeSing b   $ \sb ->
        withSomeSing i   $ \si ->
        case sInjSym2CovILists svid sdim sa sb si of
          SJust sl ->
            withSingI sl $
            case sSane sl %~ STrue of
              Proved Refl -> return $ T $ injSym2Cov' svid sdim sa sb si

someSurjSym2Con :: (Fractional v, MonadError String m) =>
                  Demote Symbol -> Demote Nat -> Demote Symbol -> Demote Symbol -> Demote Symbol ->
                  m (T v)
someSurjSym2Con vid dim a b i
    | a > b = someSurjSym2Con vid dim b a i
    | a == b = throwError $ "Invalid spacetime index for sym2 intertwiner: " ++ show a ++ " " ++ show b ++ "!"
    | otherwise =
  withSomeSing vid $ \svid ->
  withSomeSing dim $ \sdim ->
  withSomeSing a   $ \sa ->
  withSomeSing b   $ \sb ->
  withSomeSing i   $ \si ->
  case sSurjSym2ConILists svid sdim sa sb si of
    SJust sl ->
      withSingI sl $
      case sSane sl %~ STrue of
        Proved Refl -> return $ T $ surjSym2Con' svid sdim sa sb si

someSurjSym2Cov :: (Fractional v, MonadError String m) =>
                  Demote Symbol -> Demote Nat -> Demote Symbol -> Demote Symbol -> Demote Symbol ->
                  m (T v)
someSurjSym2Cov vid dim a b i
    | a > b = someSurjSym2Cov vid dim b a i
    | a == b = throwError $ "Invalid spacetime index for sym2 intertwiner: " ++ show a ++ " " ++ show b ++ "!"
    | otherwise =
        withSomeSing vid $ \svid ->
        withSomeSing dim $ \sdim ->
        withSomeSing a   $ \sa ->
        withSomeSing b   $ \sb ->
        withSomeSing i   $ \si ->
        case sSurjSym2CovILists svid sdim sa sb si of
          SJust sl ->
            withSingI sl $
            case sSane sl %~ STrue of
              Proved Refl -> return $ T $ surjSym2Cov' svid sdim sa sb si

someInterSym2Con :: Num v =>
                    Demote Symbol -> Demote Nat -> Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol ->
                    T v
someInterSym2Con vid dim m n a b = t
  where
    Right t = runExcept $
     do
       j <- someSurjSym2Con vid dim " " n a
       i <- someInjSym2Con vid dim " " m b
       product <- i .* j
       let res = contractT $ fmap ((-2) *) product
       return $ fmap (\i -> if denominator i == 1
                            then fromIntegral (numerator i)
                            else error "someInterSym2Con is not fraction-free, as it should be!") res

someInterSym2Cov :: Num v =>
                    Demote Symbol -> Demote Nat -> Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol ->
                    T v
someInterSym2Cov vid dim m n a b = t
  where
    Right t = runExcept $
      do
        j <- someSurjSym2Cov vid dim " " m a
        i <- someInjSym2Cov vid dim " " n b
        product <- i .* j
        let res = contractT $ fmap (2*) product
        return $ fmap (\i -> if denominator i == 1
                             then fromIntegral (numerator i)
                             else error "someInterSym2Cov is not fraction-free, as it should be!") res

someDeltaSym2 :: Num v => Demote Symbol -> Demote Nat -> Demote Symbol -> Demote Symbol -> T v
someDeltaSym2 id n i j = someDelta (id <> "Sym2") ((n*(n+1)) `div` 2) i j