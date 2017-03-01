
-- | Common things used in `Pos.Crypto.Arbitrary` and `Pos.Util.Arbitrary`

module Pos.Util.TimeWarp
       ( NetworkAddress
       , localhost

       , currentTime
       , addressToNodeId
       , addressToNodeId'
       , nodeIdToAddress
       ) where

import qualified Data.ByteString.Char8 as BS8
import           Data.Char             (isNumber)
import           Data.Time.Units       (Microsecond)
import           Mockable              (realTime)
import qualified Network.Transport.TCP as TCP
import           Node                  (NodeId (..))
import           Prelude               (read)
import           Universum

-- | @"127.0.0.1"@.
localhost :: ByteString
localhost = "127.0.0.1"

-- | Full node address.
type NetworkAddress = (ByteString, Word16)

-- | Temporal solution
currentTime :: MonadIO m => m Microsecond
currentTime = realTime

-- TODO: What about node index, i.e. last number in '127.0.0.1:3000:0' ?
addressToNodeId :: NetworkAddress -> NodeId
addressToNodeId = addressToNodeId' 0

addressToNodeId' :: Word32 -> NetworkAddress -> NodeId
addressToNodeId' eId (host, port) =
    NodeId $ TCP.encodeEndPointAddress (BS8.unpack host) (show port) eId

nodeIdToAddress :: NodeId -> Maybe NetworkAddress
nodeIdToAddress (NodeId ep) = toNA =<< TCP.decodeEndPointAddress ep
  where
    toNA (hostName, port', _) = (BS8.pack hostName,) <$> toPort port'
    toPort :: String -> Maybe Word16
    toPort port' | all isNumber port' = pure $ read port'
                 | otherwise          = Nothing
