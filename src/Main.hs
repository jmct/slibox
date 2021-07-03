{-# LANGUAGE OverloadedStrings #-}
module Main where

import qualified Brick.Main         as M
import qualified Brick.Widgets.List as L
import           Brick.Widgets.FileBrowser as FB

import qualified Brick.Types as T
import           Brick.Types
  ( Widget
  , BrickEvent(..)
  )

import           Brick.AttrMap
  ( AttrName )

import           Brick.Widgets.Center
  ( center
  , hCenter
  )

import           Brick.Widgets.Border
  ( borderWithLabel )

import           Brick.Widgets.Core
  ( txt
  , vBox
  , vLimit
  , hLimit
  , (<=>)
  , padTop
  , withDefAttr
  , emptyWidget )
import qualified Brick.AttrMap as A
import           Brick.Util
  ( on
  , fg
  )

import qualified Graphics.Vty as V
import qualified Data.Text as Text

import qualified Control.Exception as E

data Name = Slibox
  deriving (Eq, Show, Ord)

errorAttr :: AttrName
errorAttr = "This bad, yo"

drawUI :: FB.FileBrowser Name -> [T.Widget Name]
drawUI b = [center $ ui <=> help]
  where
    ui   = hCenter $
           vLimit 15 $
           hLimit 50 $
           borderWithLabel (txt "Choose a file") $
           FB.renderFileBrowser True b
    help = padTop (T.Pad 1) $
           vBox [ case fileBrowserException b of
                    Nothing -> emptyWidget
                    Just e  -> hCenter $ withDefAttr errorAttr $
                               txt $ Text.pack $ E.displayException e
                , hCenter $ txt "Up/Down: select"
                , hCenter $ txt "/: search, Ctrl-C or Esc: cancel search"
                , hCenter $ txt "Enter: change directory or select file"
                , hCenter $ txt "Esc: quit"
                ]

-- We only care about a few kinds of events here:
--
--  * VtyEvents
--    - Esc           -> we should halt
--    - any other key -> we should pass it on to the filebrowser
--  * Anything else   -> ignore it and continue
appEvent :: FB.FileBrowser Name -> T.BrickEvent Name e -> T.EventM Name (T.Next (FB.FileBrowser Name))
appEvent b (VtyEvent ev) =
  case ev of
    V.EvKey V.KEsc [] | not (fileBrowserIsSearching b) -> M.halt b
    _ -> do
      b' <- FB.handleFileBrowserEvent ev b
      -- If the User has pressed Enter we need to handle that possibly exit:
      case ev of
        V.EvKey V.KEnter []
          | not (null $ fileBrowserSelection b') -> M.halt b'
        _ -> M.continue b'
appEvent b _ = M.continue b

theMap :: A.AttrMap
theMap = A.attrMap V.defAttr
  [ (L.listSelectedFocusedAttr, V.black `on` V.yellow)
  , (FB.fileBrowserCurrentDirectoryAttr, V.white `on` V.blue)
  , (FB.fileBrowserSelectionInfoAttr, V.white `on` V.blue)
  , (FB.fileBrowserDirectoryAttr, fg V.blue)
  , (FB.fileBrowserBlockDeviceAttr, fg V.magenta)
  , (FB.fileBrowserCharacterDeviceAttr, fg V.green)
  , (FB.fileBrowserNamedPipeAttr, fg V.yellow)
  , (FB.fileBrowserSymbolicLinkAttr, fg V.cyan)
  , (FB.fileBrowserUnixSocketAttr, fg V.red)
  , (FB.fileBrowserSelectedAttr, V.white `on` V.magenta)
  , (errorAttr, fg V.red)
  ]

theApp :: M.App (FileBrowser Name) e Name
theApp =
  M.App { M.appDraw = drawUI
        , M.appChooseCursor = M.showFirstCursor
        , M.appHandleEvent = appEvent
        , M.appStartEvent = return
        , M.appAttrMap = const theMap
        }

main :: IO ()
main = do
  b <- M.defaultMain theApp =<< FB.newFileBrowser FB.selectNonDirectories Slibox Nothing
  putStrLn $ "Selected entry: " <> show (FB.fileBrowserSelection b)
