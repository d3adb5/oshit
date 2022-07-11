module Commands.Plumbing.Object.ListTree where

import Core.Core
import Core.Object

import qualified Data.ByteString.Char8 as B

cmdListTree :: Command
cmdListTree [hash'] = do
  let hash = B.pack hash'
  tree <- loadObjectLegacy hash :: IO Tree
  contents <- listTreeRecursive tree
  sequence_ . map putStrLn $ contents
cmdListTree _ = fail "tree not provided"
