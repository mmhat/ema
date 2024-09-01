module Ema.Server (
  EmaWebSocketOptions (..),
  runServerWithWebSocketHotReload,
  runServerWithWebSocketHotReloadOnSocket,
) where

import Control.Monad.Logger
import Data.LVar (LVar)
import Ema.CLI (Host (unHost))
import Ema.Route.Class (IsRoute (RouteModel))
import Ema.Server.HTTP (httpApp)
import Ema.Server.WebSocket (wsApp)
import Ema.Server.WebSocket.Options (EmaWebSocketOptions (..))
import Ema.Site (EmaStaticSite)
import Network.Socket (Socket, getSocketName)
import Network.Wai qualified as Wai
import Network.Wai.Handler.Warp (Port)
import Network.Wai.Handler.Warp qualified as Warp
import Network.Wai.Handler.WebSockets qualified as WaiWs
import Network.WebSockets qualified as WS
import UnliftIO (MonadUnliftIO)
import UnliftIO.Concurrent (threadDelay)

runServerWithWebSocketHotReload ::
  forall r m.
  ( Show r
  , MonadIO m
  , MonadUnliftIO m
  , MonadLoggerIO m
  , Eq r
  , IsRoute r
  , EmaStaticSite r
  ) =>
  Maybe (EmaWebSocketOptions r) ->
  Maybe Host ->
  Maybe Port ->
  LVar (RouteModel r) ->
  m ()
runServerWithWebSocketHotReload mWsOpts mhost mport model = do
  logger <- askLoggerIO
  let runM = flip runLoggingT logger
      host = fromMaybe "localhost" mhost
      settings =
        Warp.defaultSettings
          & Warp.setHost (fromString . toString . unHost $ host)
      app =
        case mWsOpts of
          Nothing ->
            httpApp @r logger model Nothing
          Just opts ->
            WaiWs.websocketsOr
              WS.defaultConnectionOptions
              (wsApp @r logger model $ emaWebSocketServerHandler opts)
              (httpApp @r logger model $ Just $ emaWebSocketClientShim opts)
      banner port = do
        logInfoNS "ema" "==============================================="
        logInfoNS "ema" $ "Ema live server RUNNING: http://" <> unHost host <> ":" <> show port <> " (" <> maybe "no ws" (const "ws") mWsOpts <> ")"
        logInfoNS "ema" "==============================================="
  liftIO $ warpRunSettings settings mport (runM . banner) app

-- Like Warp.runSettings but takes *optional* port. When no port is set, a
-- free (random) port is used.
warpRunSettings :: Warp.Settings -> Maybe Port -> (Port -> IO a) -> Wai.Application -> IO ()
warpRunSettings settings mPort banner app = do
  case mPort of
    Nothing ->
      Warp.withApplicationSettings settings (pure app) $ \port -> do
        void $ banner port
        threadDelay maxBound
    Just port -> do
      void $ banner port
      Warp.runSettings (settings & Warp.setPort port) app

-- | A version of 'runServerWithWebSocketHotReload' that runs on a pre-allocated
-- socket.
runServerWithWebSocketHotReloadOnSocket ::
  forall r m.
  ( Show r
  , MonadIO m
  , MonadUnliftIO m
  , MonadLoggerIO m
  , Eq r
  , IsRoute r
  , EmaStaticSite r
  ) =>
  Maybe (EmaWebSocketOptions r) ->
  Socket ->
  LVar (RouteModel r) ->
  m ()
runServerWithWebSocketHotReloadOnSocket mWsOpts socket model = do
  logger <- askLoggerIO
  let settings = Warp.defaultSettings
      app =
        case mWsOpts of
          Nothing ->
            httpApp @r logger model Nothing
          Just opts ->
            WaiWs.websocketsOr
              WS.defaultConnectionOptions
              (wsApp @r logger model $ emaWebSocketServerHandler opts)
              (httpApp @r logger model $ Just $ emaWebSocketClientShim opts)
      banner = do
        addr <- liftIO $ getSocketName socket
        logInfoNS "ema" "==============================================="
        logInfoNS "ema" $ "Ema live server RUNNING: Socket " <> show addr <> " (" <> maybe "no ws" (const "ws") mWsOpts <> ")"
        logInfoNS "ema" "==============================================="
  void banner
  liftIO $ Warp.runSettingsSocket settings socket app
