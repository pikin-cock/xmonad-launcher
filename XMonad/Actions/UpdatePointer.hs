-----------------------------------------------------------------------------
-- |
-- Module      :  XMonadContrib.UpdatePointer
-- Copyright   :  (c) Robert Marlow <robreim@bobturf.org>
-- License     :  BSD3-style (see LICENSE)
-- 
-- Maintainer  :  Robert Marlow <robreim@bobturf.org>
-- Stability   :  stable
-- Portability :  portable
--
-- Causes the pointer to follow whichever window focus changes to. Compliments
-- the idea of switching focus as the mouse crosses window boundaries to
-- keep the mouse near the currently focused window
--
-----------------------------------------------------------------------------

module XMonad.Actions.UpdatePointer 
    (
     -- * Usage
     -- $usage
     updatePointer
     , PointerPosition (..)
    )
    where

import XMonad
import Control.Monad
import XMonad.StackSet (member, peek, screenDetail, current)

-- $usage
-- You can use this module with the following in your @~\/.xmonad\/xmonad.hs@:
--
-- > import XMonad
-- > import XMonad.Actions.UpdatePointer
--
-- Enable it by including it in your logHook definition. Eg:
-- 
-- > logHook = updatePointer Nearest
-- 
-- which will move the pointer to the nearest point of a newly focused window, or
--
-- > logHook = updatePointer (Relative 0.5 0.5)
--
-- which will move the pointer to the center of a newly focused window.
--
-- To use this with an existing logHook, use >> :
--
-- > logHook = dynamicLog
-- >           >> updatePointer (Relative 1 1)
--
-- which moves the pointer to the bottom-right corner of the focused window.

data PointerPosition = Nearest | Relative Rational Rational

-- | Update the pointer's location to the currently focused
-- window or empty screen unless it's already there, or unless the user was changing
-- focus with the mouse
updatePointer :: PointerPosition -> X ()
updatePointer p = do
  ws <- gets windowset
  dpy <- asks display
  rect <- case peek ws of
		Nothing -> return $ (screenRect . screenDetail .current) ws
		Just w  -> windowAttributesToRectangle `fmap` io (getWindowAttributes dpy w)
  root <- asks theRoot
  mouseIsMoving <- asks mouseFocused
  (_sameRoot,_,currentWindow,rootx,rooty,_,_,_) <- io $ queryPointer dpy root
  unless (pointWithin (fi rootx) (fi rooty) rect
          || mouseIsMoving
          || not (currentWindow `member` ws || currentWindow == none)) $
    case p of
    Nearest -> do
      let x = moveWithin (fi rootx) (rect_x rect) (fi (rect_x rect) + fi (rect_width  rect))
          y = moveWithin (fi rooty) (rect_y rect) (fi (rect_y rect) + fi (rect_height rect))
      io $ warpPointer dpy none root 0 0 0 0 x y
    Relative h v ->
      io $ warpPointer dpy none root 0 0 0 0
           (rect_x rect + fraction h (rect_width rect))
           (rect_y rect + fraction v (rect_height rect))
        where fraction x y = floor (x * fromIntegral y)

windowAttributesToRectangle :: WindowAttributes -> Rectangle
windowAttributesToRectangle wa = Rectangle (fi (wa_x wa))     (fi (wa_y wa))
                                           (fi (wa_width wa)) (fi (wa_height wa))
moveWithin :: Ord a => a -> a -> a -> a
moveWithin now lower upper =
    if now < lower
    then lower
    else if now > upper
         then upper
         else now

pointWithin :: Position -> Position -> Rectangle -> Bool
pointWithin x y r = x >= rect_x r &&
		    x <  rect_x r + fi (rect_width r) &&
		    y >= rect_y r &&
		    y <  rect_y r + fi (rect_height r)

fi :: (Num b, Integral a) => a -> b
fi = fromIntegral 

