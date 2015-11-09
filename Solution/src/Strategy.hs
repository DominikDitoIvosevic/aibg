{-# LANGUAGE RecordWildCards #-}
module Strategy where

import Data.Vector.Unboxed (Vector)
import qualified Data.Vector.Unboxed as Vec
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Int
import Data.Ord
import Data.List
import Hilbert
import Combinations

newtype Moves = Moves [(Int, Int)]

type CellState = Int8

empty, ally, enemy :: Int8
(empty, ally, enemy) = (0, 1, 2)

data GameState = GameState { field :: Vector Int8
                           , ammo  :: Int }
                           deriving (Eq, Ord, Show)

gridHeight, gridWidth :: Int
(gridHeight, gridWidth) = (24, 24)

gridIdx :: [(Int, Int)]
gridIdx = grid
-- gridIdx = [(x, y) | x <- [0..gridWidth - 1], y <- [0..gridHeight - 1]]

oneOffset :: [(Int, Int)]
oneOffset = [(x, y) | x <- [-1..1], y <- [-1..1], x /= 0 || y /= 0]

twoOffset :: [(Int, Int)]
twoOffset = [(x, y) | x <- [-2..2], y <- [-2..2], x /= 0 || y /= 0]

at :: GameState -> (Int, Int) -> CellState
(st@GameState{..}) `at` (x, y) = field Vec.! idx (x, y)

coords :: Int -> (Int, Int)
coords n = let (d, r) = n `divMod` gridWidth in (r, d)

idx :: (Int, Int) -> Int
idx (x, y)
    |    x >= 0 && x < gridWidth
      && y >= 0 && y < gridHeight = x + y * gridWidth
    | otherwise                   = idx (x `mod` gridWidth, y `mod` gridHeight)

numCell :: CellState -> Int8
numCell c | c == empty = 0
          | c == ally  = 1
          | c == enemy = -1

neighbors :: GameState -> (Int, Int) -> Int8
neighbors gs (x, y) = s
    where s = sum $ map (\(i, j) -> numCell $ gs `at` (x + i, y + j)) oneOffset

legal :: GameState -> (Int, Int) -> Bool
legal gs (x, y) = gs `at` (x, y) == empty && close
    where all2Neigh = map (\(i, j) -> gs `at` (x + i, y + j)) oneOffset
          close     = ally `elem` all2Neigh

logic :: (Int, Int) -> CellState -> GameState -> CellState
logic (x, y) st gs = case () of
    _ | st == empty && ns == 3            -> ally
      | st == empty && ns == -3           -> enemy
      | st == empty                       -> empty
      | st == ally && ns `elem` [2, 3]    -> ally
      | st == enemy && ns `elem` [-2, -3] -> enemy
      | otherwise                         -> empty
      where ns = neighbors gs (x, y)

advance :: GameState -> GameState
advance gs = gs { field = Vec.imap (\i st -> logic (coords i) st gs) (field gs) }

reduce :: Int -> [a] -> [a]
reduce _ [] = []
reduce n xs = head (take n xs) : reduce n (drop n xs)

allMoves :: GameState -> [(Int, Int)]
allMoves gs = moves
    where moves = filter (legal gs) gridIdx

windows :: Int -> [a] -> [[a]]
windows n xs = take (length xs - n + 1) $ map (take n) $ tails xs

moveWindows :: Int -> [(Int, Int)] -> [Moves]
moveWindows k mvs = map Moves $ windows k mvs

evaluate :: GameState -> Int8
evaluate gs = sum $ map (numCell . (gs `at`)) gridIdx

goodness :: GameState -> Moves -> Int8
goodness (gs@GameState{..}) (Moves mvs) = evaluate $ advance $ gs { field = newField }
    where newField = field Vec.// map (\(x, y) -> (idx (x, y), ally)) mvs

decide :: GameState -> Moves
decide gs = maximumBy (comparing (goodness gs)) allCombos
    where mvs       = allMoves gs
          allCombos = moveWindows 3 mvs ++ bestOf
          sorted1   = sortBy (flip $ comparing (goodness gs . Moves . return)) mvs
          bestOf    = map Moves $ twoCombinations $ take 20 sorted1