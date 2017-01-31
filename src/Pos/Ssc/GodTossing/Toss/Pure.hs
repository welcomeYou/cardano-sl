-- | Pure Toss.

module Pos.Ssc.GodTossing.Toss.Pure
       ( PureToss (..)
       , runPureToss
       , runPureTossWithLogger
       , evalPureTossWithLogger
       ) where

import           Control.Lens                   (at, to, (%=), (.=))
import           Control.Monad.RWS.Strict       (RWS, runRWS)
import           System.Wlog                    (CanLog, HasLoggerName (getLoggerName),
                                                 LogEvent, LoggerName, LoggerNameBox,
                                                 PureLogger, WithLogger, dispatchEvents,
                                                 runPureLog, usingLoggerName)
import           Universum

import           Pos.Lrc.Types                  (RichmenSet)
import           Pos.Ssc.GodTossing.Core        (SignedCommitment, VssCertificatesMap,
                                                 deleteSignedCommitment,
                                                 getCommitmentsMap,
                                                 insertSignedCommitment)
import           Pos.Ssc.GodTossing.Toss.Class  (MonadToss (..), MonadTossRead (..))
import           Pos.Ssc.GodTossing.Types       (GtGlobalState, gsCommitments, gsOpenings,
                                                 gsShares, gsVssCertificates)
import qualified Pos.Ssc.GodTossing.VssCertData as VCD
import           Pos.Types                      (EpochIndex, StakeholderId)

newtype PureToss a = PureToss
    { getPureToss :: LoggerNameBox (PureLogger (RWS (EpochIndex, RichmenSet) () GtGlobalState)) a
    } deriving (Functor, Applicative, Monad, CanLog, HasLoggerName)

instance MonadTossRead PureToss where
    getCommitment id =
        PureToss $ use $ gsCommitments . to getCommitmentsMap . at id
    hasOpening id = PureToss $ use $ gsOpenings . at id . to isJust
    hasShares id = PureToss $ use $ gsShares . at id . to isJust
    hasCertificate id =
        PureToss $ use $ gsVssCertificates . to VCD.certs . at id . to isJust
    getStableCertificates _ = notImplemented
    getRichmen epoch = PureToss $ getRichmenDo <$> ask
      where
        getRichmenDo (e, r)
            | e == epoch = Just r
            | otherwise = Nothing

instance MonadToss PureToss where
    putCommitment signedComm =
        PureToss $ gsCommitments %= insertSignedCommitment signedComm
    putOpening id op = PureToss $ gsOpenings . at id .= Just op
    putShares id sh = PureToss $ gsShares . at id .= Just sh
    putCertificate cert =
        PureToss $ gsVssCertificates %= VCD.insert cert
    delCommitment id =
        PureToss $ gsCommitments %= deleteSignedCommitment id
    delOpening id = PureToss $ gsOpenings . at id .= Nothing
    delShares id = PureToss $ gsOpenings . at id .= Nothing
    setEpochOrSlot eos = PureToss $ gsVssCertificates %= VCD.setLastKnownEoS eos

runPureToss
    :: LoggerName
    -> (EpochIndex, RichmenSet)
    -> GtGlobalState
    -> PureToss a
    -> (a, GtGlobalState, [LogEvent])
runPureToss loggerName richmenData gs =
    convertRes .
    (\a -> runRWS a richmenData gs) .
    runPureLog . usingLoggerName loggerName . getPureToss
  where
    convertRes :: ((a, [LogEvent]), GtGlobalState, ())
               -> (a, GtGlobalState, [LogEvent])
    convertRes ((res, logEvents), newGs, ()) = (res, newGs, logEvents)

runPureTossWithLogger
    :: WithLogger m
    => (EpochIndex, RichmenSet)
    -> GtGlobalState
    -> PureToss a
    -> m (a, GtGlobalState)
runPureTossWithLogger richmenData gs action = do
    loggerName <- getLoggerName
    let (res, newGS, events) = runPureToss loggerName richmenData gs action
    (res, newGS) <$ dispatchEvents events

evalPureTossWithLogger
    :: WithLogger m
    => (EpochIndex, RichmenSet) -> GtGlobalState -> PureToss a -> m a
evalPureTossWithLogger r g = fmap fst . runPureTossWithLogger r g
