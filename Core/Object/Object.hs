module Core.Object.Object where

import qualified Codec.Compression.Zlib     as Zlib
import qualified Crypto.Hash.SHA1           as SHA1
import qualified Data.ByteString.Base16     as B16
import qualified Data.ByteString.Char8      as B
import qualified Data.ByteString.Lazy.Char8 as L
import qualified System.Directory           as Dir

import Core.Core

type ObjectType = B.ByteString

class Object obj where
  objectType       :: obj -> ObjectType
  objectParse      :: B.ByteString -> IO obj
  objectRawContent :: obj -> B.ByteString

hashObject :: Object obj => obj -> Hash
hashObject = B16.encode . SHA1.hash . objectFileContent

compress :: B.ByteString -> B.ByteString
compress = L.toStrict . Zlib.compress . L.fromStrict

decompress :: B.ByteString -> B.ByteString
decompress = L.toStrict . Zlib.decompress . L.fromStrict

storeObject :: Object obj => obj -> IO ()
storeObject obj = do
  Dir.createDirectoryIfMissing True completeDir
  B.writeFile path compressed
  where hashStr      = B.unpack $ hashObject obj
        dir          = take 2 $ hashStr
        filename     = drop 2 $ hashStr
        completeDir  = concat [".git/objects/", dir, "/"]
        path         = completeDir ++ filename
        uncompressed = objectFileContent obj
        compressed   = compress uncompressed


loadObject :: Object obj => Hash -> IO obj
loadObject hash = loadRawObject hash >>= objectParse

loadRawObject :: B.ByteString -> IO B.ByteString
loadRawObject hash = do
  let hashStr  = B.unpack hash
  let dir      = take 2 $ hashStr
  let filename = drop 2 $ hashStr
  let path     = concat [".git/objects/", dir, "/", filename]

  B.readFile path >>= return . decompress

objectFileContent :: Object obj => obj -> B.ByteString
objectFileContent obj = uncompressed
  where content      = objectRawContent obj
        size         = B.pack $ show $ B.length content
        objType      = objectType obj
        uncompressed = B.concat [objType, B.pack " ", size, B.pack "\0", content]