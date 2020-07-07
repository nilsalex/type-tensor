{-# OPTIONS_GHC 
    -Wall
    -Werror
    -Weverything
    -Wno-prepositive-qualified-module
    -Wno-missing-deriving-strategies
    -Wno-implicit-prelude
    -Wno-missing-import-lists
    -Wno-missing-safe-haskell-mode
    -Wno-unsafe
    #-}

-----------------------------------------------------------------------------
{-|
Module      : Math.Tensor.LinearAlgebra
Description : Linear algebra for tensor equations.
Copyright   : (c) Nils Alex, 2020
License     : MIT
Maintainer  : nils.alex@fau.de
Stability   : experimental

Linear algebra for tensor equations.
-}
-----------------------------------------------------------------------------
module Math.Tensor.LinearAlgebra
  ( -- * Linear combinations and polynomials
    -- ** Data types
    Lin(..)
  , Poly(..)
  , -- ** Construction, inspection, modification
    singletonPoly
  , polyMap
  , getVars
  , shiftVars
  , normalize
  , -- * Tensor equations
    -- ** Extracting tensor equations and matrix representations
    Equation
  , tensorToEquations
  , tensorsToSparseMat
  , tensorsToMat
  , -- ** Rank of a linear tensor equation system
    systemRank
  , -- ** Solutions
    Solution
  , solveTensor
  , solveSystem
  , redefineIndets
  , -- ** Internals
    equationFromRational
  , equationsToSparseMat
  , equationsToMat
  , fromRref
  , fromRow
  , applySolution
  ) where

import Math.Tensor.LinearAlgebra.Scalar
import Math.Tensor.LinearAlgebra.Equations
