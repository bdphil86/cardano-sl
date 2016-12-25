{-# LANGUAGE CPP                   #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes            #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE UndecidableInstances  #-}

module Pos.Ssc.GodTossing.LocalData.Types
#ifdef MODERN
       ( GtLocalData (..)
       , ldCommitments
       , ldOpenings
       , ldShares
       , ldCertificates
       , ldLastProcessedSlot
       ) where
#else
       ( GtLocalData (..)
       , gtLocalCommitments
       , gtLocalOpenings
       , gtLocalShares
       , gtLocalCertificates
       , gtLastProcessedSlot
       , gtGlobalCommitments
       , gtGlobalOpenings
       , gtGlobalShares
       , gtGlobalCertificates
       ) where
#endif

import           Control.Lens                  (makeLenses)
import           Data.Default                  (Default (def))
import           Universum

import           Pos.Crypto                    (PublicKey)
import           Pos.Ssc.GodTossing.Genesis    (genesisCertificates)
import           Pos.Ssc.GodTossing.Types.Base (CommitmentsMap, OpeningsMap, PKSet,
                                                SharesMap, VssCertificatesMap)
import           Pos.Types                     (SlotId, unflattenSlotId)
import           Pos.Types.Address             (AddressHash)

#ifdef MODERN
data GtLocalData = GtLocalData
    { -- | Local set of 'Commitment's. These are valid commitments which are
      -- known to the node and not stored in blockchain. It is useful only
      -- for the first 'k' slots, after that it should be discarded.
      _ldCommitments       :: !CommitmentsMap
    , -- | Local set of openings
      _ldOpenings          :: !OpeningsMap
    , -- | Local set of decrypted shares (encrypted shares are stored in
      -- commitments).
      _ldShares            :: !SharesMap
    , -- | Local set of VSS certificates
      _ldCertificates      :: !VssCertificatesMap
    , -- | Last slot we are aware of.
      _ldLastProcessedSlot :: !SlotId
    }
makeLenses ''GtLocalData

instance Default GtLocalData where
    def =
        GtLocalData
        { _ldCertificates = mempty
        , _ldShares = mempty
        , _ldOpenings = mempty
        , _ldCommitments = mempty
        , _ldLastProcessedSlot = unflattenSlotId 0
        }
#else
data GtLocalData = GtLocalData
    { -- | Local set of 'Commitment's. These are valid commitments which are
      -- known to the node and not stored in blockchain. It is useful only
      -- for the first 'k' slots, after that it should be discarded.
      _gtLocalCommitments   :: !CommitmentsMap
    , -- | Local set of openings
      _gtLocalOpenings      :: !OpeningsMap
    , -- | Local set of decrypted shares (encrypted shares are stored in
      -- commitments).
      _gtLocalShares        :: !SharesMap
    , -- | Local set of VSS certificates
      _gtLocalCertificates  :: !VssCertificatesMap
    , -- | Last slot we are aware of.
      _gtLastProcessedSlot  :: !SlotId
    , -- | Last version of global commitments
      _gtGlobalCommitments  :: !CommitmentsMap
    , -- | Last version of global openings
      _gtGlobalOpenings     :: !PKSet
    , -- | Last version of global certificates
      _gtGlobalShares       :: !(HashMap (AddressHash PublicKey) PKSet)
    , -- | Global certificates
      _gtGlobalCertificates :: !VssCertificatesMap
    }
makeLenses ''GtLocalData

instance Default GtLocalData where
    def =
        GtLocalData
        { _gtLocalCertificates = mempty
        , _gtLocalShares = mempty
        , _gtLocalOpenings = mempty
        , _gtLocalCommitments = mempty
        , _gtLastProcessedSlot = unflattenSlotId 0
        , _gtGlobalCommitments = mempty
        , _gtGlobalOpenings = mempty
        , _gtGlobalShares = mempty
        , _gtGlobalCertificates = genesisCertificates
        }
#endif
