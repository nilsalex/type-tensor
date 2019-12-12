{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE EmptyCase #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE NoStarIsType #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE StandaloneDeriving #-}

module Tensor where

import TH
import Internal

import Data.Kind (Type)

import Data.Singletons
import Data.Singletons.Prelude
import Data.Singletons.Prelude.Ord
import Data.Singletons.Prelude.List
import Data.Singletons.Prelude.List.NonEmpty (SNonEmpty((:%|)))
import Data.Singletons.Decide
import Data.Singletons.TypeLits

import Data.List (foldl')
import Data.List.NonEmpty (NonEmpty((:|)))

data Tensor :: ILists -> Type -> Type where
    ZeroTensor :: forall (l :: ILists) v . Sane l ~ 'True => Tensor l v
    Scalar :: forall (l :: ILists) v.  l ~ '[] => v -> Tensor l v
    Tensor :: forall (l :: ILists) (l' :: ILists) v.
              (Sane l ~ 'True, Tail' l ~ l') =>
              [(Int, Tensor l' v)] -> Tensor l v

deriving instance Eq v => Eq (Tensor l v)

instance (SingI l, Show v) => Show (Tensor l v) where
  show = show . toRep

type IxR = Ix (Demote Symbol)
type VSpaceR = VSpace (Demote Symbol) (Demote Nat)
type IListR = IList (Demote Symbol)
type IListsR = [(VSpaceR, IListR)]

data TensorR :: Type -> Type where
  ZeroTensorR :: IListsR -> TensorR v
  ScalarR :: v -> TensorR v
  TensorR :: (VSpaceR, IxR) -> [(Int, TensorR v)] -> TensorR v
    deriving (Show, Eq)

toRep :: forall (l :: ILists) v.SingI l => Tensor l v -> TensorR v
toRep ZeroTensor = let sl = sing :: Sing l
                   in ZeroTensorR $ fromSing sl
toRep (Scalar s) = ScalarR s
toRep (Tensor ms) = let sl  = sTail' (sing :: Sing l)
                        sp  = sHead' (sing :: Sing l)
                        ms' = fmap (fmap (\t -> withSingI sl $ toRep t)) ms
                    in TensorR (fromSing sp) ms'

fromRep :: forall l v.SingI l => TensorR v -> Either String (Tensor l v)
fromRep (ScalarR s) = case (sing :: Sing l) of
                        SNil -> Right $ Scalar s
                        _    -> Left "cannot construct Scalar with non-empty index list"
fromRep (ZeroTensorR lr) =
  case toSing lr of
    SomeSing sl' -> case sl' %~ (sing :: Sing l) of
      Proved Refl -> case sSane (sing :: Sing l) of
        STrue  -> Right ZeroTensor
        SFalse -> Left "insane indices in ZeroTensor"
      _           -> Left "indices in ZeroTensorR don't match type to be constructed"
fromRep (TensorR (vr, ir) ms) =
  case (sing :: Sing l) of
    SNil -> Left "cannot reconstruct Tensor with empty index list"
    _    ->
      case toSing vr of
        SomeSing sv -> case toSing ir of
          SomeSing si -> case STuple2 sv si %~ sHead' (sing :: Sing l) of
            Proved Refl -> case sSane (sing :: Sing l) of
              STrue  ->
               let sl  = sTail' (sing :: Sing l)
                   ms' = fmap (fmap (\t -> withSingI sl $ fromRep t)) ms
                   ms'' = filter (\(_, e) -> case e of
                                               Left _ -> False
                                               Right _ -> True) ms'
                   ms''' = fmap (fmap (\e -> case e of
                                               Right t -> t)) ms''
               in case ms''' of
                    [] -> Left "empty tensor"
                    _  -> Right $ Tensor ms'''
              SFalse -> Left "insane indices in Tensor"
            _           -> Left "indices in TensorR don't match type to be constructed"

removeZeros :: (Num v, Eq v) => Tensor l v -> Tensor l v
removeZeros ZeroTensor = ZeroTensor
removeZeros (Scalar s) = if s == 0 then ZeroTensor else Scalar s
removeZeros (Tensor ms) =
    case ms' of
      [] -> ZeroTensor
      _  -> Tensor ms'
  where
    ms' = filter
     (\(_, t) ->
        case t of
          ZeroTensor -> False
          _          -> True) $
            fmap (fmap removeZeros) ms

(&+) :: forall (l :: ILists) (l' :: ILists) v.
        ((l ~ l'), Num v, Eq v) =>
        Tensor l v -> Tensor l' v -> Tensor l v
(&+) ZeroTensor t = t
(&+) t ZeroTensor = t
(&+) (Scalar s) (Scalar s') = let s'' = s + s' in
                              if s'' == 0
                              then ZeroTensor
                              else Scalar s''
(&+) (Tensor xs) (Tensor xs') = removeZeros $ Tensor xs''
    where
       xs'' = unionWith (&+) id id xs xs' 

infixl 6 &+

negateT :: forall (l :: ILists) v. Num v =>
           Tensor l v -> Tensor l v
negateT ZeroTensor = ZeroTensor
negateT (Scalar s) = Scalar $ negate s
negateT (Tensor x) = Tensor $ fmap (fmap negateT) x

(&-) :: forall (l :: ILists) (l' :: ILists) v.
        ((l ~ l'), Num v, Eq v) =>
        Tensor l v -> Tensor l' v -> Tensor l v
(&-) t1 t2 = t1 &+ (negateT t2)

infixl 6 &-

(&*) :: forall (l :: ILists) (l' :: ILists) (l'' :: ILists) v.
               (Num v, l'' ~ MergeILs l l', Sane l'' ~ 'True,
                SingI l, SingI l') =>
               Tensor l v -> Tensor l' v -> Tensor l'' v
(&*) (Scalar s) (Scalar t) = Scalar (s*t)
(&*) (Scalar s) (Tensor ms) =
  let sl' = sTail' (sing :: Sing l')
  in case sSane sl' of
      STrue -> Tensor $ fmap (fmap (\t -> withSingI sl' $ Scalar s &* t)) ms
(&*) (Tensor ms) (Scalar s) =
  let sl = sTail' (sing :: Sing l)
  in case sSane sl of
      STrue -> Tensor $ fmap (fmap (\t -> withSingI sl $ t &* Scalar s)) ms
(&*) (Tensor ms) (Tensor ms') =
  let sl = sing :: Sing l
      sl' = sing :: Sing l'
      sh = sHead' sl
      sh' = sHead' sl'
      st = sTail' sl
      st' = sTail' sl'
      sl'' = sMergeILs sl sl'
  in case sSane sl'' of
       STrue -> case sSane (sTail' sl'') of
         STrue -> case sh of
           STuple2 sv si ->
             case sh' of
               STuple2 sv' si' ->
                 case sCompare sv sv' of
                   SLT -> case sMergeILs st sl' %~ sTail' sl'' of
                            Proved Refl -> Tensor $ fmap (fmap (\t -> withSingI st $ t &* (Tensor ms' :: Tensor l' v))) ms
                   SGT -> case sMergeILs sl st' %~ sTail' sl'' of
                            Proved Refl -> Tensor $ fmap (fmap (\t -> withSingI st' $ (Tensor ms :: Tensor l v) &* t)) ms'
                   SEQ -> case sIxCompare si si' of
                            SLT -> case sMergeILs st sl' %~ sTail' sl'' of
                                     Proved Refl -> Tensor $ fmap (fmap (\t -> withSingI st $ t &* (Tensor ms' :: Tensor l' v))) ms
                            SEQ -> case sMergeILs st sl' %~ sTail' sl'' of
                                     Proved Refl -> Tensor $ fmap (fmap (\t -> withSingI st $ t &* (Tensor ms' :: Tensor l' v))) ms
                            SGT -> case sMergeILs sl st' %~ sTail' sl'' of
                                     Proved Refl -> Tensor $ fmap (fmap (\t -> withSingI st' $ (Tensor ms :: Tensor l v) &* t)) ms'
(&*) ZeroTensor _ = ZeroTensor
(&*) _ ZeroTensor = ZeroTensor

infixl 7 &*

contract :: forall (l :: ILists) (l' :: ILists) v.
            (l' ~ ContractL l, SingI l, Num v, Eq v)
            => Tensor l v -> Tensor l' v
contract ZeroTensor = let sl' = sContractL (sing :: Sing l)
                      in case sSane sl' of
                           STrue -> ZeroTensor
contract (Scalar v) = Scalar v
contract (Tensor ms) =
    let sl = sing :: Sing l
        sl' = sContractL sl
        st = sTail' sl
    in case st of
         SNil -> case sl %~ sContractL sl of
                   Proved Refl -> Tensor ms
         _    -> case sSane sl' of
                   STrue -> 
                     let st' = sTail' st
                         sh  = sHead' sl
                         sv  = sFst sh
                         si  = sSnd sh
                         sh' = sHead' st
                         sv' = sFst sh'
                         si' = sSnd sh'
                         t'  = withSingI st $
                               case sTail' sl' %~ sContractL st of
                                 Proved Refl -> removeZeros $ Tensor $ fmap (fmap contract) ms
                     in case sv %~ sv' of
                          Disproved _ -> t'
                          Proved Refl -> case si of
                            SICov sa -> case si' of
                              SICon sb -> case sa %~ sb of

                                Proved Refl -> 
                                          let ms' = fmap (\(i, v) -> case v of
                                                                       Tensor vs ->
                                                                         case filter (\(i', _) -> i == i') vs of
                                                                              [] -> Nothing
                                                                              (_, (v')):[] -> Just v'
                                                                              _ -> error "duplicate key in tensor assoc list") ms
                                              ms'' = filter (\x -> case x of
                                                                     Nothing -> False
                                                                     Just x' -> True) ms'
                                              ms''' = fmap (\(Just x) -> x) ms'' :: [Tensor (Tail' (Tail' l)) v]
                                          in case st' %~ sl' of
                                                    Proved Refl -> foldl' (&+) ZeroTensor ms'''
                                                    Disproved _ -> case sContractL st' %~ sl' of
                                                                     Proved Refl -> case sSane st' of
                                                                                      STrue -> withSingI (st') $ contract $ foldl' (&+) ZeroTensor ms'''

                                Disproved _ -> t'
                              _        -> t'
                            _        -> t'

toList :: forall l v.SingI l => Tensor l v -> [([Int], v)]
toList ZeroTensor = []
toList (Scalar s) = [([], s)]
toList (Tensor ms) =
  let st = sTail' (sing :: Sing l)
  in case st of
       SNil -> fmap (\(i, Scalar s)  -> ([i], s)) ms
       _    -> concat $ fmap (\(i, v) -> case v of Tensor t -> fmap (\(is, v') -> (i:is, v')) (withSingI st $ toList v)) ms

delta :: forall (id :: Symbol) (n :: Nat) (a :: Symbol) (b :: Symbol) (l :: ILists) v.
         (
          '[ '( 'VSpace id n, 'CovCon (a :| '[]) (b :| '[]))] ~ l,
          Tail' (Tail' l) ~ '[],
          Sane (Tail' l) ~ 'True,
          SingI n,
          Num v
         ) => Tensor l v
delta = case (sing :: Sing n) of
          sn -> let x = fromIntegral $ withKnownNat sn $ natVal sn
                in Tensor (f x)
  where
    f x = map (\i -> (i, Tensor [(i, Scalar 1)])) [0..x - 1]

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
    f x = map (\i -> (i, Tensor [(i, Scalar (if i == 0 then -1 else 1))])) [0..x - 1]

type V4 = 'VSpace "Spacetime" 4
type Up2 a b = 'Cov (a :| '[b])
type UpDown a b = 'CovCon (a :| '[]) (b :| '[])

d_ap :: Tensor '[ '(V4, UpDown "p" "a") ] Rational
d_ap = delta

d_aq :: Tensor '[ '(V4, UpDown "q" "a") ] Rational
d_aq = delta

d_bp :: Tensor '[ '(V4, UpDown "p" "b") ] Rational
d_bp = delta

d_bq :: Tensor '[ '(V4, UpDown "q" "b") ] Rational
d_bq = delta

e_ab :: Tensor '[ '(V4, Up2 "a" "b") ] Rational
e_ab = eta

someFunc :: IO ()
someFunc = putStrLn "someFunc"
