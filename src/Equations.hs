module Equations where

import Tensor
import Scalar
import LinearAlgebra

import qualified Numeric.LinearAlgebra.Data as HM

import Data.Maybe (mapMaybe)
import qualified Data.IntMap.Strict as IM
import Data.List (nub,sort)
import Data.Ratio

tensorToEquations :: Integral a => T (Poly Rational) -> [IM.IntMap a]
tensorToEquations = nub . sort . fmap (equationFromRational . normalize . snd) . toListT

equationFromRational :: Integral a => Poly Rational -> IM.IntMap a
equationFromRational (Affine x (Lin lin))
    | x == 0 = lin'
    | otherwise = error "affine equation not supported for the moment!"
  where
    fac = IM.foldl' (\acc v -> lcm (fromIntegral (denominator v)) acc) 1 lin
    lin' = IM.map (\v -> fromIntegral (numerator (fromIntegral fac * v))) lin
equationFromRational _ = error ""

equationsToSparseMat :: Integral a => [IM.IntMap a] -> [((Int,Int), a)]
equationsToSparseMat xs = concat $ zipWith (\i m -> fmap (\(j,v) -> ((i,j),v)) (IM.assocs m)) [1..] xs

equationsToMat :: Integral a => [IM.IntMap a] -> [[a]]
equationsToMat eqns = mapMaybe (\m -> if IM.null m
                                      then Nothing
                                      else Just $ fmap (\j -> IM.findWithDefault 0 j m) [1..maxVar]) eqns
  where
    maxVar = maximum $ mapMaybe ((fmap fst) . IM.lookupMax) eqns

tensorsToSparseMat :: Integral a => [T (Poly Rational)] -> [((Int,Int), a)]
tensorsToSparseMat = equationsToSparseMat . concat . fmap tensorToEquations

tensorsToMat :: Integral a => [T (Poly Rational)] -> [[a]]
tensorsToMat = equationsToMat . concat . fmap tensorToEquations

type Solution = IM.IntMap (Poly Rational)

fromRref :: HM.Matrix HM.Z -> Solution
fromRref ref = IM.fromList assocs
  where
    rows   = HM.toLists ref
    assocs = mapMaybe fromRow rows

fromRow :: Integral a => [a] -> Maybe (Int, Poly Rational)
fromRow xs = case assocs of
               []             -> Nothing
               [(i,_)]        -> Just (i, Affine 0 (Lin IM.empty))
               (i, v):assocs' -> let assocs'' = fmap (\(i,v') -> (i, - (fromIntegral v') / (fromIntegral v))) assocs
                                 in Just (i, Affine 0 (Lin (IM.fromList assocs'')))
  where
    assocs = filter ((/=0). snd) $ zip [1..] xs

applySolution :: Solution -> Poly Rational -> Poly Rational
applySolution s (Affine x (Lin lin))
    | x == 0 = Affine x (Lin lin')
    | otherwise = error "affine equations not yet supported"
  where
    s' = IM.intersectionWith (\row v -> polyMap (v*) row) s lin
    lin' = IM.foldlWithKey' (\lin' i sub -> let Affine 0 (Lin lin'') = Affine 0 (Lin lin') + sub
                                            in IM.delete i lin'') lin s'

solveTensor :: Solution -> T (Poly Rational) -> T (Poly Rational)
solveTensor sol = removeZerosT . fmap (applySolution sol)

solveSystem :: [T (Poly Rational)] -> [T (Poly Rational)] -> [T (Poly Rational)]
solveSystem system indets
    | wrongSolution = error "Wrong solution found. May be an Int64 overflow."
    | otherwise     = indets'
  where
    mat = HM.fromLists $ tensorsToMat system
    ref = rref mat
    wrongSolution = not (isrref ref && verify mat ref)
    sol = fromRref ref
    indets' = fmap (solveTensor sol) indets

redefineIndets :: [T (Poly v)] -> [T (Poly v)]
redefineIndets indets = fmap (fmap (\v -> case v of
                                            Const c -> Const c
                                            NotSupported -> NotSupported
                                            Affine a (Lin lin) ->
                                              Affine a (Lin (IM.mapKeys (varMap IM.!) lin)))) indets
  where
    comps = fmap snd $ concat $ fmap toListT indets
    vars = nub $ concat $ mapMaybe (\v -> case v of
                                            Affine _ (Lin lin) -> Just $ IM.keys lin
                                            _                  -> Nothing) comps
    varMap = IM.fromList $ zip vars [1..]
