{-# LANGUAGE OverloadedStrings #-}

module Example where

import Area
import Ansaetze
import Delta
import Sym2
import DiffeoSymmetry
import Tensor
import TH
import Scalar

import Control.Monad.Except

calc :: (Num v, Eq v) => Either String (T v)
calc = runExcept $ do
    e_ab <- someEtaInv "Spacetime" 4 "a" "b"
    e_ac <- someEtaInv "Spacetime" 4 "a" "c"
    prod1 <- e_ab .* d_cp
    prod2 <- e_ac .* d_bp
    prod1 .+ prod2
  where
    d_cp = someDelta "Spacetime" 4 "c" "p"
    d_bp = someDelta "Spacetime" 4 "b" "p"

ans4Test :: (Num v, Eq v) => Either String (T (Poly v))
ans4Test = runExcept $ do
  let c = someInterAreaCon "ST" "m" "n" "A" "B"
  let a = someAns4 "ST" "A"
  eta <- someEtaInv "ST" 4 "p" "n"
  p1 <- c .* a
  p2 <- p1 .* eta
  let contracted = contractT p2
  trans <- transposeT (VSpace "ST" 4) (ICon "m") (ICon "p") contracted
  contracted .- trans

ans6Test :: (Num v, Eq v) => Either String (T (Poly v))
ans6Test = runExcept $ do
  let c = someInterAreaJet2 "ST" "m" "n" "A" "B" "I" "J"
  let a = someAns6 "ST" "A" "I"
  eta <- someEtaInv "ST" 4 "p" "n"
  p1 <- c .* a
  p2 <- p1 .* eta
  let contracted = contractT p2
  trans <- transposeT (VSpace "ST" 4) (ICon "m") (ICon "p") contracted
  contracted .- trans

ans8Test :: (Num v, Eq v) => Either String (T (Poly v))
ans8Test = runExcept $ do
  let c = someInterAreaCon "ST" "m" "n" "A" "C"
  a <- someAns8 "ST" "A" "B"
  eta <- someEtaInv "ST" 4 "p" "n"
  p1 <- c .* a
  p2 <- p1 .* eta
  let contracted = contractT p2
  trans <- transposeT (VSpace "ST" 4) (ICon "m") (ICon "p") contracted
  sym1 <- contracted .- trans
  trans' <- transposeT (VSpace "STArea" 21) (ICov "B") (ICov "C") sym1
  sym1 .+ trans'

ans10_1Test :: (Num v, Eq v) => Either String (T (Poly v))
ans10_1Test = runExcept $ do
  let c1 = someInterAreaCon "ST" "m" "n" "C" "A"
  let c2 = someInterAreaJet2 "ST" "m" "n" "C" "B" "J" "I"
  eta <- someEtaInv "ST" 4 "x" "n"
  a1 <- someAns10_1 "ST" "C" "B" "I"
  a2 <- someAns10_1 "ST" "A" "C" "J"
  t1 <- fmap contractT $ a1 .* c1
  t2 <- fmap contractT $ a2 .* c2
  tens <- fmap contractT $ (eta .*) =<< (t1 .+ t2)
  (tens .-) =<< transposeT (VSpace "ST" 4) (ICon "m") (ICon "x") tens

ans10_2Test :: (Num v, Eq v) => Either String (T (Poly v))
ans10_2Test = runExcept $ do
  c <- someInterAreaJet1 "ST" "m" "n" "A" "C" "p" "r"
  a <- someAns10_2 "ST" "A" "B" "p" "q"
  eta <- someEtaInv "ST" 4 "x" "n"
  t <- fmap contractT $ (a .*) =<< (c .* eta)
  t' <- (t .-) =<< transposeT (VSpace "ST" 4) (ICon "m") (ICon "x") t
  (t' .+) =<< (transposeT (VSpace "STArea" 21) (ICov "B") (ICov "C") =<<
               transposeT (VSpace "ST" 4) (ICon "q") (ICon "r") t')
