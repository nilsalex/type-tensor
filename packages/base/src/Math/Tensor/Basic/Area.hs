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

-----------------------------------------------------------------------------
{-|
Module      : Math.Tensor.Basic.Area
Description : Definitions of area-symmetric tensors.
Copyright   : (c) Nils Alex, 2020
License     : MIT
Maintainer  : nils.alex@fau.de
Stability   : experimental

Definitions of area-symmetric tensors.
-}
-----------------------------------------------------------------------------
module Math.Tensor.Basic.Area
  ( -- * Area metric tensor induced from flat Lorentzian metric
    flatAreaCon
  , someFlatAreaCon
  ,  -- * Injections from \(AS(V)\) into \(V\times V\times V\times V\)
    injAreaCon'
  , injAreaCov'
  , someInjAreaCon
  , someInjAreaCov
  , -- * Surjections from \(V\times V\times V\times V\) onto \(AS(V)\)
    surjAreaCon'
  , surjAreaCov'
  , someSurjAreaCon
  , someSurjAreaCov
  , -- * Vertical coefficients for functions on \(AS(V)\)
    someInterAreaCon
  , someInterAreaCov
  , -- * Kronecker delta on \(AS(V)\)
    someDeltaArea
  , -- * Internals
    trianMapArea
  , facMapArea
  , areaSign
  , sortArea
  ) where

import Math.Tensor
import Math.Tensor.Safe
import Math.Tensor.Safe.TH
import Math.Tensor.Basic.TH
import Math.Tensor.Basic.Delta

import Data.Singletons
import Data.Singletons.Prelude
import Data.Singletons.Decide
import Data.Singletons.TypeLits

import Data.Maybe (catMaybes)
import Data.Ratio
import qualified Data.Map.Strict as Map
import Data.List.NonEmpty (NonEmpty(..))
import Control.Monad.Except

trianMapArea :: Map.Map (Vec (S (S (S (S Z)))) Int) Int
trianMapArea = Map.fromList $ zip indices4 indices1
  where
    indices1 = [0..]
    indices4 = [a `VCons` (b `VCons` (c `VCons` (d `VCons` VNil))) |
                  a <- [0..2],
                  b <- [a+1..3],
                  c <- [a..2],
                  d <- [c+1..3],
                  not (a == c && b > d) ]

facMapArea :: Num b => Map.Map (Vec (S (S (S (S Z)))) Int) b
facMapArea = Map.fromList $ [(a `VCons` (b `VCons` (c `VCons` (d `VCons` VNil))), fac a b c d) |
                                a <- [0..2],
                                b <- [a+1..3],
                                c <- [a..2],
                                d <- [c+1..3],
                                not (a == c && b > d)]
  where
    fac a b c d
      | a == c && b == d = 4
      | otherwise        = 8

areaSign :: (Ord a, Num v) => a -> a -> a -> a -> Maybe v
areaSign a b c d
  | a == b = Nothing
  | c == d = Nothing
  | a > b  = ((-1) *) <$> areaSign b a c d
  | c > d  = ((-1) *) <$> areaSign a b d c
  | otherwise = Just 1

sortArea :: Ord a => a -> a -> a -> a -> Vec (S (S (S (S Z)))) a
sortArea a b c d
  | a > b = sortArea b a c d
  | c > d = sortArea a b d c
  | (a,b) > (c,d) = sortArea c d a b
  | otherwise = a `VCons` (b `VCons` (c `VCons` (d `VCons` VNil)))


injAreaCon' :: forall (id :: Symbol) (a :: Symbol) (b :: Symbol) ( c :: Symbol) (d :: Symbol)
                     (i :: Symbol) (r :: Rank) v.
               (
                InjAreaConRank id a b c d i ~ 'Just r,
                SingI r,
                Num v
               ) => Sing id -> Sing a -> Sing b -> Sing c -> Sing d -> Sing i -> Tensor r v
injAreaCon' sid sa sb sc sd si =
    case sLengthR sr of
      SS (SS (SS (SS (SS SZ)))) ->
        case sSane sr %~ STrue of
          Proved Refl -> fromList assocs
  where
    sr = sing :: Sing r
    tm = trianMapArea
    assocs = catMaybes $
             (\a b c d ->
                  do
                     s <- areaSign a b c d
                     let v = sortArea a b c d
                     i <- Map.lookup v tm
                     return (a `VCons` (b `VCons` (c `VCons` (d `VCons` (i `VCons` VNil)))), s :: v))
             <$> [0..3] <*> [0..3] <*> [0..3] <*> [0..3]

injAreaCov' :: forall (id :: Symbol) (a :: Symbol) (b :: Symbol) ( c :: Symbol) (d :: Symbol)
                     (i :: Symbol) (r :: Rank) v.
               (
                InjAreaCovRank id a b c d i ~ 'Just r,
                SingI r,
                Num v
               ) => Sing id -> Sing a -> Sing b -> Sing c -> Sing d -> Sing i -> Tensor r v
injAreaCov' sid sa sb sc sd si =
    case sLengthR sr of
      SS (SS (SS (SS (SS SZ)))) ->
        case sSane sr %~ STrue of
          Proved Refl -> fromList assocs
  where
    sr = sing :: Sing r
    tm = trianMapArea
    assocs = catMaybes $
             (\a b c d ->
                  do
                     s <- areaSign a b c d
                     let v = sortArea a b c d
                     i <- Map.lookup v tm
                     return (a `VCons` (b `VCons` (c `VCons` (d `VCons` (i `VCons` VNil)))), s :: v))
             <$> [0..3] <*> [0..3] <*> [0..3] <*> [0..3]

surjAreaCon' :: forall (id :: Symbol) (a :: Symbol) (b :: Symbol) ( c :: Symbol) (d :: Symbol)
                     (i :: Symbol) (r :: Rank) v.
               (
                SurjAreaConRank id a b c d i ~ 'Just r,
                SingI r,
                Fractional v
               ) => Sing id -> Sing a -> Sing b -> Sing c -> Sing d -> Sing i -> Tensor r v
surjAreaCon' sid sa sb sc sd si =
    case sLengthR sr of
      SS (SS (SS (SS (SS SZ)))) ->
        case sSane sr %~ STrue of
          Proved Refl -> fromList assocs
  where
    sr = sing :: Sing r
    tm = trianMapArea
    fm = facMapArea
    assocs = catMaybes $
             (\a b c d ->
                  do
                     s <- areaSign a b c d
                     let v = sortArea a b c d
                     i <- Map.lookup v tm
                     f <- Map.lookup v fm
                     return (a `VCons` (b `VCons` (c `VCons` (d `VCons` (i `VCons` VNil)))), s/f :: v))
             <$> [0..3] <*> [0..3] <*> [0..3] <*> [0..3]

surjAreaCov' :: forall (id :: Symbol) (a :: Symbol) (b :: Symbol) ( c :: Symbol) (d :: Symbol)
                     (i :: Symbol) (r :: Rank) v.
               (
                SurjAreaCovRank id a b c d i ~ 'Just r,
                SingI r,
                Fractional v
               ) => Sing id -> Sing a -> Sing b -> Sing c -> Sing d -> Sing i -> Tensor r v
surjAreaCov' sid sa sb sc sd si =
    case sLengthR sr of
      SS (SS (SS (SS (SS SZ)))) ->
        case sSane sr %~ STrue of
          Proved Refl -> fromList assocs
  where
    sr = sing :: Sing r
    tm = trianMapArea
    fm = facMapArea
    assocs = catMaybes $
             (\a b c d ->
                  do
                     s <- areaSign a b c d
                     let v = sortArea a b c d
                     i <- Map.lookup v tm
                     f <- Map.lookup v fm
                     return (a `VCons` (b `VCons` (c `VCons` (d `VCons` (i `VCons` VNil)))), s/f :: v))
             <$> [0..3] <*> [0..3] <*> [0..3] <*> [0..3]

_injAreaCon :: Num v => Demote Symbol -> Demote Symbol -> T v
_injAreaCon id i =
  withSomeSing id    $ \sid ->
  withSomeSing i     $ \si  ->
  withSomeSing " 01" $ \s01 ->
  withSomeSing " 02" $ \s02 ->
  withSomeSing " 03" $ \s03 ->
  withSomeSing " 04" $ \s04 ->
    case sInjAreaConRank sid s01 s02 s03 s04 si of
      SJust sr -> withSingI sr $ T $ injAreaCon' sid s01 s02 s03 s04 si

_injAreaCov :: Num v => Demote Symbol -> Demote Symbol -> T v
_injAreaCov id i =
  withSomeSing id    $ \sid ->
  withSomeSing i     $ \si  ->
  withSomeSing " 01" $ \s01 ->
  withSomeSing " 02" $ \s02 ->
  withSomeSing " 03" $ \s03 ->
  withSomeSing " 04" $ \s04 ->
    case sInjAreaCovRank sid s01 s02 s03 s04 si of
      SJust sr -> withSingI sr $ T $ injAreaCov' sid s01 s02 s03 s04 si

_surjAreaCon :: Fractional v => Demote Symbol -> Demote Symbol -> T v
_surjAreaCon id i =
  withSomeSing id    $ \sid ->
  withSomeSing i     $ \si  ->
  withSomeSing " 01" $ \s01 ->
  withSomeSing " 02" $ \s02 ->
  withSomeSing " 03" $ \s03 ->
  withSomeSing " 04" $ \s04 ->
    case sSurjAreaConRank sid s01 s02 s03 s04 si of
      SJust sr -> withSingI sr $ T $ surjAreaCon' sid s01 s02 s03 s04 si

_surjAreaCov :: Fractional v => Demote Symbol -> Demote Symbol -> T v
_surjAreaCov id i =
  withSomeSing id    $ \sid ->
  withSomeSing i     $ \si  ->
  withSomeSing " 01" $ \s01 ->
  withSomeSing " 02" $ \s02 ->
  withSomeSing " 03" $ \s03 ->
  withSomeSing " 04" $ \s04 ->
    case sSurjAreaCovRank sid s01 s02 s03 s04 si of
      SJust sr -> withSingI sr $ T $ surjAreaCov' sid s01 s02 s03 s04 si

someInjAreaCon :: forall v m.(Num v, MonadError String m) =>
                  Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol ->
                  m (T v)
someInjAreaCon vid a b c d i = relabelT (VSpace vid 4) [(" 01",a), (" 02",b), (" 03",c), (" 04",d)] t
  where
    t = _injAreaCon vid i :: T v

someInjAreaCov :: forall v m.(Num v, MonadError String m) =>
                  Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol ->
                  m (T v)
someInjAreaCov vid a b c d i = relabelT (VSpace vid 4) [(" 01",a), (" 02",b), (" 03",c), (" 04",d)] t
  where
    t = _injAreaCov vid i :: T v

someSurjAreaCon :: forall v m.(Fractional v, MonadError String m) =>
                  Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol ->
                  m (T v)
someSurjAreaCon vid a b c d i = relabelT (VSpace vid 4) [(" 01",a), (" 02",b), (" 03",c), (" 04",d)] t
  where
    t = _surjAreaCon vid i :: T v

someSurjAreaCov :: forall v m.(Fractional v, MonadError String m) =>
                  Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol ->
                  m (T v)
someSurjAreaCov vid a b c d i = relabelT (VSpace vid 4) [(" 01",a), (" 02",b), (" 03",c), (" 04",d)] t
  where
    t = _surjAreaCov vid i :: T v

someInterAreaCon :: Num v =>
                    Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol ->
                    T v
someInterAreaCon vid m n a b = t
  where
    Right t = runExcept $
      do
        j <- someSurjAreaCon vid " 1" " 2" " 3" n a
        i <- someInjAreaCon vid " 1" " 2" " 3" m b
        product <- i .* j
        let res = contractT $ fmap (*(-4)) product
        return $ fmap (\i -> if denominator i == 1
                             then fromIntegral (numerator i)
                             else error "someInterAreaCon is not fraction-free, as it should be!") res

someInterAreaCov :: Num v =>
                    Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol -> Demote Symbol ->
                    T v
someInterAreaCov vid m n a b = t
  where
    Right t = runExcept $
      do
        j <- someSurjAreaCov vid " 1" " 2" " 3" m a
        i <- someInjAreaCov vid " 1" " 2" " 3" n b
        product <- i .* j
        let res = contractT $ fmap (*4) product
        return $ fmap (\i -> if denominator i == 1
                             then fromIntegral (numerator i)
                             else error "someInterAreaCov is not fraction-free, as it should be!") res

someDeltaArea :: Num v => Demote Symbol -> Demote Symbol -> Demote Symbol -> T v
someDeltaArea id a b = someDelta (id <> "Area") 21 a b

flatAreaCon :: forall (id :: Symbol) (a :: Symbol) (r :: Rank) v.
               (
                '[ '( 'VSpace (id <> "Area") 21, 'Con (a :| '[]))] ~ r,
                Num v
               ) => Sing id -> Sing a -> Tensor r v
flatAreaCon sid sa =
  withKnownSymbol (sid `sMappend` (sing :: Sing "Area")) $
  withKnownSymbol sa $
  fromList [(0 `VCons` VNil, -1), (5 `VCons` VNil, 1),   --  0  1  2  3  4  5
            (6 `VCons` VNil, -1), (9 `VCons` VNil, -1),  --     6  7  8  9 10
            (11 `VCons` VNil, -1), (12 `VCons` VNil, 1), --       11 12 13 14
            (15 `VCons` VNil, 1),                        --          15 16 17
            (18 `VCons` VNil, 1),                        --             18 19
            (20 `VCons` VNil, 1)]                        --                20



someFlatAreaCon :: Num v => Demote Symbol -> Demote Symbol -> T v
someFlatAreaCon id a =
  withSomeSing id $ \sid ->
  withSomeSing a  $ \sa  ->
  withKnownSymbol (sid `sMappend` (sing :: Sing "Area")) $
  withKnownSymbol sa $
  T $ flatAreaCon sid sa