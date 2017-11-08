-- Classes and datatypes for managing extra context in Explorer.

{-# LANGUAGE RankNTypes #-}

module Pos.Explorer.ExtraContext
    ( ExtraContext (..)
    , ExtraContextT
    , runExtraContextT
    , makeExtraCtx

    , HasGenesisRedeemAddressInfo (..)
    , GenesisRedeemAddressInfo
    -- ^ Genesis address info

    , HasExplorerCSLInterface (..)
    , ExplorerMockableMode (..)
    , makeMockExtraCtx
    -- ^ Explorer mock interface

    ) where

import           Universum

import qualified Data.Vector     as V
import qualified Ether

import           Data.Default    (Default (..), def)
import           Pos.Block.Core  (Block)
import           Pos.Block.Types (Blund)
import           Pos.DB.Block    (MonadBlockDB, blkGetBlund)
import           Pos.DB.Class    (MonadDBRead)
import           Pos.DB.DB       (getTipBlock)

import           Pos.Explorer.DB (Page, getPageBlocks)

import           Pos.Core        (Address, Coin, HasConfiguration, isRedeemAddress)
import           Pos.Lrc         (getLeadersForEpoch)
import           Pos.Slotting    (MonadSlotsData, getSlotStart)
import           Pos.Txp         (GenesisUtxo (..), genesisUtxo, utxoToAddressCoinPairs)
import           Pos.Types       (EpochIndex, HeaderHash, SlotId (..), SlotLeaders,
                                  Timestamp)


-------------------------------------------------------------------------------------
-- Extra context
-------------------------------------------------------------------------------------

type ExtraContextT m = Ether.ReaderT' ExtraContext m

runExtraContextT :: Monad m => ExtraContext -> ExtraContextT m a -> m a
runExtraContextT = flip Ether.runReaderT

data ExtraContext = ExtraContext
    { ecAddressCoinPairs     :: GenesisRedeemAddressInfo
    , ecExplorerMockableMode :: ExplorerMockableMode
    }

makeExtraCtx :: HasConfiguration => ExtraContext
makeExtraCtx =
    let addressCoinPairs = utxoToAddressCoinPairs $ unGenesisUtxo genesisUtxo
        redeemOnly = filter (isRedeemAddress . fst) addressCoinPairs
    in ExtraContext
        { ecAddressCoinPairs     = V.fromList redeemOnly
        , ecExplorerMockableMode = prodMode
        }

-- | For mocking we mostly need to replace just the external CSL functions.
makeMockExtraCtx :: HasConfiguration => ExplorerMockableMode -> ExtraContext
makeMockExtraCtx explorerMockMode =
    ExtraContext
        { ecAddressCoinPairs = V.empty
        , ecExplorerMockableMode = explorerMockMode
        }

-------------------------------------------------------------------------------------
-- Genesis redeem address info
-------------------------------------------------------------------------------------

type GenesisRedeemAddressInfo = V.Vector (Address, Coin)

class HasGenesisRedeemAddressInfo m where
    getGenesisRedeemAddressInfo :: m GenesisRedeemAddressInfo

instance Monad m => HasGenesisRedeemAddressInfo (ExtraContextT m) where
    getGenesisRedeemAddressInfo = do
        extraCtx <- Ether.ask @ExtraContext
        pure $ ecAddressCoinPairs extraCtx

-------------------------------------------------------------------------------------
-- Explorer mock mode
--
-- The simple data structure that encapsulates functions that use CSL. We want to "cut"
-- them out of the picture in order to be able to mock them.
-------------------------------------------------------------------------------------

data ExplorerMockableMode = ExplorerMockableMode
    { emmGetTipBlock
          :: forall m. MonadBlockDB m => m Block
    , emmGetPageBlocks
          :: forall m. MonadDBRead m => Page -> m (Maybe [HeaderHash])
    , emmGetBlundFromHH
          :: forall m. MonadBlockDB m => HeaderHash -> m (Maybe Blund)
    , emmGetSlotStart
          :: forall ctx m. MonadSlotsData ctx m => SlotId -> m (Maybe Timestamp)
    , emmGetLeadersFromEpoch
          :: forall m. MonadDBRead m => EpochIndex -> m (Maybe SlotLeaders)
    }

-- | This is what we use in production when we run Explorer.
prodMode :: ExplorerMockableMode
prodMode = ExplorerMockableMode {
      emmGetTipBlock            = getTipBlock,
      emmGetPageBlocks          = getPageBlocks,
      emmGetBlundFromHH         = blkGetBlund,
      emmGetSlotStart           = getSlotStart,
      emmGetLeadersFromEpoch    = getLeadersForEpoch
    }

-- | So we can just reuse the default instance and change individial functions.
-- On one side, it removes the compile error(s) for having all functions implemented.
-- On the other side, it moves that error into runtime and enables simple mocking.
-- This is a good thing once we have a larger amount of functions, like in _explorer_,
-- and this gives us the flexibility to "mock" whichever we want.
instance Default (ExplorerMockableMode) where
  def = ExplorerMockableMode {
        emmGetTipBlock            = errorImpl,
        emmGetPageBlocks          = errorImpl,
        emmGetBlundFromHH         = errorImpl,
        emmGetSlotStart           = errorImpl,
        emmGetLeadersFromEpoch    = errorImpl
      }
    where
      errorImpl = error "Cannot be used, please implement this function!"


-------------------------------------------------------------------------------------
-- Explorer interface instance
-------------------------------------------------------------------------------------

-- | We use this for an external CSL functions representation so we can mock them when
-- testing.
class HasExplorerCSLInterface m where
    getTipBlockCSLI :: m Block
    getPageBlocksCSLI :: Page -> m (Maybe [HeaderHash])
    getBlundFromHHCSLI :: HeaderHash -> m (Maybe Blund)
    getSlotStartCSLI :: SlotId -> m (Maybe Timestamp)
    getLeadersFromEpochCSLI :: EpochIndex -> m (Maybe SlotLeaders)

-- | The instance for external CSL functions.
instance (Monad m, MonadBlockDB m, MonadDBRead m, MonadSlotsData ctx m) =>
    HasExplorerCSLInterface (ExtraContextT m) where

    getTipBlockCSLI = do
        extraCtx <- Ether.ask @ExtraContext
        let explorerMockMode = ecExplorerMockableMode extraCtx
        emmGetTipBlock explorerMockMode

    getPageBlocksCSLI page = do
        extraCtx <- Ether.ask @ExtraContext
        let explorerMockMode = ecExplorerMockableMode extraCtx
        emmGetPageBlocks explorerMockMode $ page

    getBlundFromHHCSLI headerHash = do
        extraCtx <- Ether.ask @ExtraContext
        let explorerMockMode = ecExplorerMockableMode extraCtx
        emmGetBlundFromHH explorerMockMode $ headerHash

    getSlotStartCSLI slotId = do
        extraCtx <- Ether.ask @ExtraContext
        let explorerMockMode = ecExplorerMockableMode extraCtx
        emmGetSlotStart explorerMockMode $ slotId

    getLeadersFromEpochCSLI epochIndex = do
        extraCtx <- Ether.ask @ExtraContext
        let explorerMockMode = ecExplorerMockableMode extraCtx
        emmGetLeadersFromEpoch explorerMockMode $ epochIndex