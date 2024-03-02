module Foreign.Storable(Storable(..)) where
import Prelude()              -- do not import Prelude
import Primitives
import Control.Error(undefined)
import Foreign.C.Types
import Foreign.Ptr
import Data.Word

class Storable a where
   sizeOf      :: a -> Int
   alignment   :: a -> Int
   peekElemOff :: Ptr a -> Int      -> IO a
   pokeElemOff :: Ptr a -> Int -> a -> IO ()
   peekByteOff :: forall b . Ptr b -> Int      -> IO a
   pokeByteOff :: forall b . Ptr b -> Int -> a -> IO ()
   peek        :: Ptr a      -> IO a
   poke        :: Ptr a -> a -> IO ()

   peekElemOff ptr off     = peekByteOff ptr (off `primIntMul` sizeOf (undefined :: a))
   pokeElemOff ptr off val = pokeByteOff ptr (off `primIntMul` sizeOf val) val

   peekByteOff ptr off = peek (ptr `plusPtr` off)
   pokeByteOff ptr off = poke (ptr `plusPtr` off)

   peek ptr = peekElemOff ptr 0
   poke ptr = pokeElemOff ptr 0

foreign import ccall "peekWord" c_peekWord :: Ptr Word -> IO Word
foreign import ccall "pokeWord" c_pokeWord :: Ptr Word -> Word -> IO ()

wordSizeInBytes :: Int
wordSizeInBytes = _wordSize `primIntQuot` 8

instance Storable Word where
  sizeOf    _ = wordSizeInBytes
  alignment _ = wordSizeInBytes
  peek p      = c_peekWord p
  poke p w    = c_pokeWord p w

instance Storable Int where
  sizeOf    _ = wordSizeInBytes
  alignment _ = wordSizeInBytes
  peek p      = c_peekWord (castPtr p) `primBind` \ w -> primReturn (primWordToInt w)
  poke p w    = c_pokeWord (castPtr p) (primIntToWord w)

foreign import ccall "peekPtr" c_peekPtr :: Ptr (Ptr ()) -> IO (Ptr ())
foreign import ccall "pokePtr" c_pokePtr :: Ptr (Ptr ()) -> Ptr () -> IO ()

instance forall a . Storable (Ptr a) where
  sizeOf    _ = wordSizeInBytes
  alignment _ = wordSizeInBytes
  peek p      = c_peekPtr (castPtr p) `primBind` \ q -> primReturn (castPtr q)
  poke p w    = c_pokePtr (castPtr p) (castPtr w)

foreign import ccall "peek_uint8" c_peek_uint8 :: Ptr Word8 -> IO Word8
foreign import ccall "poke_uint8" c_poke_uint8 :: Ptr Word8 -> Word8 -> IO ()

instance Storable Word8 where
  sizeOf    _ = 1
  alignment _ = 1
  peek p      = c_peek_uint8 p
  poke p w    = c_poke_uint8 p w

{-
foreign import ccall "peek_uint16" c_peek_uint16 :: Ptr Word16 -> IO Word16
foreign import ccall "poke_uint16" c_poke_uint16 :: Ptr Word16 -> Word16 -> IO ()

instance Storable Word16 where
  sizeOf    _ = 1
  alignment _ = 1
  peek p      = c_peek_uint16 p
  poke p w    = c_poke_uint16 p w

foreign import ccall "peek_uint32" c_peek_uint32 :: Ptr Word32 -> IO Word32
foreign import ccall "poke_uint32" c_poke_uint32 :: Ptr Word32 -> Word32 -> IO ()

instance Storable Word32 where
  sizeOf    _ = 1
  alignment _ = 1
  peek p      = c_peek_uint32 p
  poke p w    = c_poke_uint32 p w

foreign import ccall "peek_uint64" c_peek_uint64 :: Ptr Word64 -> IO Word64
foreign import ccall "poke_uint64" c_poke_uint64 :: Ptr Word64 -> Word64 -> IO ()

instance Storable Word64 where
  sizeOf    _ = 1
  alignment _ = 1
  peek p      = c_peek_uint64 p
  poke p w    = c_poke_uint64 p w
-}

{-
foreign import ccall "peek_int8" c_peek_int8 :: Ptr Int8 -> IO Int8
foreign import ccall "poke_int8" c_poke_int8 :: Ptr Int8 -> Int8 -> IO ()

instance Storable Int8 where
  sizeOf    _ = 1
  alignment _ = 1
  peek p      = c_peek_int8 p
  poke p w    = c_poke_int8 p w

foreign import ccall "peek_int16" c_peek_int16 :: Ptr Int16 -> IO Int16
foreign import ccall "poke_int16" c_poke_int16 :: Ptr Int16 -> Int16 -> IO ()

instance Storable Int16 where
  sizeOf    _ = 1
  alignment _ = 1
  peek p      = c_peek_int16 p
  poke p w    = c_poke_int16 p w

foreign import ccall "peek_int32" c_peek_int32 :: Ptr Int32 -> IO Int32
foreign import ccall "poke_int32" c_poke_int32 :: Ptr Int32 -> Int32 -> IO ()

instance Storable Int32 where
  sizeOf    _ = 1
  alignment _ = 1
  peek p      = c_peek_int32 p
  poke p w    = c_poke_int32 p w

foreign import ccall "peek_int64" c_peek_int64 :: Ptr Int64 -> IO Int64
foreign import ccall "poke_int64" c_poke_int64 :: Ptr Int64 -> Int64 -> IO ()

instance Storable Int64 where
  sizeOf    _ = 1
  alignment _ = 1
  peek p      = c_peek_int64 p
  poke p w    = c_poke_int64 p w
-}

foreign import ccall "peek_int" c_peek_int :: Ptr CInt -> IO CInt
foreign import ccall "poke_int" c_poke_int :: Ptr CInt -> CInt -> IO ()

instance Storable CInt where
  sizeOf    _ = 1
  alignment _ = 1
  peek p      = c_peek_int p
  poke p w    = c_poke_int p w

foreign import ccall "peek_uint" c_peek_uint :: Ptr CUInt -> IO CUInt
foreign import ccall "poke_uint" c_poke_uint :: Ptr CUInt -> CUInt -> IO ()

instance Storable CUInt where
  sizeOf    _ = 1
  alignment _ = 1
  peek p      = c_peek_uint p
  poke p w    = c_poke_uint p w
