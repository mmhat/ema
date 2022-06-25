{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE UndecidableSuperClasses #-}

-- | WIP https://github.com/srid/ema/issues/92
module Ema.Multi.Generic.Motley where

import Data.SOP.Constraint (AllZipF)
import Data.SOP.NS (trans_NS)
import Ema.Multi (MultiModel, MultiRoute)
import Ema.Multi.Generic.RGeneric (RGeneric (..))
import Generics.SOP
import Optics.Core (
  Iso',
  iso,
 )
import Prelude hiding (All, Generic)

{- | MotleyRoute is a class of routes with an underlying MultiRoute (and MultiModel) representation.

 The idea is that by deriving MotleyRoute (and MotleyModel), we get IsRoute for free (based on MultiRoute).

 TODO: Rename this class, or change the API.
-}
class MotleyRoute r where
  -- | The sub-routes in the `r` (for each constructor).
  type MotleyRouteSubRoutes r :: [Type] -- TODO: Derive this generically

  motleyRouteIso :: Iso' r (MultiRoute (MotleyRouteSubRoutes r))
  default motleyRouteIso ::
    ( RGeneric r
    , SameShapeAs (RCode r) (MotleyRouteSubRoutes r)
    , SameShapeAs (MotleyRouteSubRoutes r) (RCode r)
    , All Top (RCode r)
    , All Top (MotleyRouteSubRoutes r)
    , AllZipF Coercible (RCode r) (MotleyRouteSubRoutes r)
    , AllZipF Coercible (MotleyRouteSubRoutes r) (RCode r)
    ) =>
    Iso' r (MultiRoute (MotleyRouteSubRoutes r))
  motleyRouteIso =
    iso (gtoMotley @r . rfrom) (rto . gfromMotley @r)

gtoMotley ::
  forall r.
  ( RGeneric r
  , SameShapeAs (RCode r) (MotleyRouteSubRoutes r)
  , SameShapeAs (MotleyRouteSubRoutes r) (RCode r)
  , All Top (RCode r)
  , All Top (MotleyRouteSubRoutes r)
  , AllZipF Coercible (RCode r) (MotleyRouteSubRoutes r)
  ) =>
  NS I (RCode r) ->
  MultiRoute (MotleyRouteSubRoutes r)
gtoMotley = trans_NS (Proxy @Coercible) coerce

gfromMotley ::
  forall r.
  ( RGeneric r
  , SameShapeAs (RCode r) (MotleyRouteSubRoutes r)
  , SameShapeAs (MotleyRouteSubRoutes r) (RCode r)
  , All Top (RCode r)
  , All Top (MotleyRouteSubRoutes r)
  , AllZipF Coercible (MotleyRouteSubRoutes r) (RCode r)
  ) =>
  MultiRoute (MotleyRouteSubRoutes r) ->
  NS I (RCode r)
gfromMotley = trans_NS (Proxy @Coercible) coerce

class MotleyRoute r => MotleyModel r where
  type MotleyModelType r :: Type

  -- | Break the model into a list of sub-models used correspondingly by the sub-routes.
  motleySubModels :: MotleyModelType r -> NP I (MultiModel (MotleyRouteSubRoutes r))
