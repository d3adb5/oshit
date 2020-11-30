module Core.Object.Tree where

import Data.List.Split
import qualified Data.ByteString.Char8      as B
import qualified Data.Map                   as Map
import qualified Data.ByteString.Base16     as B16

import Core.Core
import Core.Stage
import Core.Object.Object

type FileMode = String

data Tree = Tree [(FileMode, FilePath, Hash)]

data InnerTreeNode = InnerLeaf Hash
                   | InnerTree FilePath (Map.Map FilePath InnerTreeNode)

data HashedInnerTree = HashedInnerTree (Hash, Tree, [HashedInnerTree])

instance Object Tree where
  objectType _ = B.pack "tree"

  objectParse _ = fail "not implemented"

  objectRawContent (Tree children) = B.concat $
    [[ B.pack mode, B.pack " "
     , B.pack name, B.pack "\0"
     , hash
     ]
    | (mode, name, hash) <- children
    ] >>= return . B.concat

treesFromStage :: Stage -> [Tree]
treesFromStage stage = trees
  where splittedStage = [ (hash, splitOn "/" path)
                        | (hash, path) <- stage
                        ]

        files = [ (hash, init path, last path)
                | (hash, path) <- splittedStage
                ]

        filesystem = foldl insertToInnerTree (InnerTree "" Map.empty) files

        trees = treesFromInnerTrees filesystem
        
insertToInnerTree :: InnerTreeNode
                  -> (Hash, [FilePath], FilePath)
                  -> InnerTreeNode
insertToInnerTree (InnerTree treeName nodes) (hash, [], childName) =
  InnerTree treeName $
  Map.insert childName (InnerLeaf hash) nodes
insertToInnerTree (InnerTree treeName nodes) (hash, root:innerPath, childName) =
  InnerTree treeName $
  Map.insertWith joinTree root newChild nodes
  where newChild = insertToInnerTree emptyInnerTree (hash, innerPath, childName)
        joinTree (InnerTree n a) (InnerTree _ b) = InnerTree n $ a `Map.union` b
        joinTree _ x = x
        emptyInnerTree = InnerTree root Map.empty
insertToInnerTree _ _ = InnerTree "" Map.empty

treesFromInnerTrees :: InnerTreeNode -> [Tree]
treesFromInnerTrees (InnerTree _ nodes) = (Tree content) : descendentTrees
  where nodeList = Map.toList nodes

        blobEntries :: [(FileMode, FilePath, Hash)]
        blobEntries = do
          (name, child) <- nodeList
          case child of (InnerTree _ _) -> []
                        (InnerLeaf hash) -> [
                          ("100644", name, (fst . B16.decode $ hash))
                          ]

        descendentTrees' :: [(FilePath, [Tree])] 
        descendentTrees' = [ (name, [c | c <- treesFromInnerTrees child])
                           | (name, child) <- nodeList]

        childTrees :: [(FilePath, Tree)]
        childTrees = [ (name, head trees)
                     | (name, trees) <- descendentTrees'
                     , length trees > 0
                     ]

        descendentTrees :: [Tree]
        descendentTrees = descendentTrees' >>= snd

        treeEntries :: [(FileMode, FilePath, Hash)]
        treeEntries = do
          (name, tree) <- childTrees
          [ ("040000", name, (fst . B16.decode . hashObject $ tree)) ]

        content = blobEntries ++ treeEntries
treesFromInnerTrees _ = []