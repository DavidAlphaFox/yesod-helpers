{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}
module Main where

import Prelude
import System.Exit
import Text.Parsec
import Database.Persist
import Data.ByteString.Base16               as B16
import qualified Data.ByteString.Char8      as C8

import Network                              (PortID(..))

import Yesod.Helpers.Types
import Yesod.Helpers.Parsec
import Yesod.Helpers.FuzzyDay

import Data.SafeCopy
import Data.Serialize
import Yesod.Helpers.SafeCopy


testVerValidate :: VerConstraint -> SimpleVersion -> Bool -> IO ()
testVerValidate c v b = do
    if validateSimpleVersion c v /= b
        then do
            putStrLn $ "constaint '" ++ show c ++ "' validate version '" ++ show v
                        ++ "' does not get expected result: " ++ show b
            exitFailure
        else return ()

tryVerConstraintParse :: String -> IO VerConstraint
tryVerConstraintParse s = do
    case parse simpleParser "" s of
        Left err -> do
            putStrLn $ "failed to parse " ++ show s ++ ": " ++ show err
            exitFailure
        Right x -> return x

testAnyCharParser :: (Eq a, Show a) => CharParser a -> String -> a -> IO ()
testAnyCharParser p s expected = do
    case parse p "" s of
        Left err -> do
            putStrLn $ "failed to parse " ++ show s ++ ": " ++ show err
            exitFailure
        Right x -> do
            if x == expected
                then return ()
                else do
                    putStrLn $ "failed to parse " ++ show s ++ "to expected result"
                    putStrLn $ "expected: " ++ show expected
                    putStrLn $ "actual: " ++ show x
                    exitFailure


testVerConstraint :: IO ()
testVerConstraint = do
    testVerValidate (VerWithOrder GT $ SimpleVersion [0, 9]) (SimpleVersion [1]) True
    testVerValidate (VerWithOrder GT $ SimpleVersion [1]) (SimpleVersion [1, 0]) True
    tryVerConstraintParse "> 0.9"
        >>= flip (flip testVerValidate $ SimpleVersion [1]) True
    tryVerConstraintParse "> 1.0"
        >>= flip (flip testVerValidate $ SimpleVersion [1, 0, 1]) True
    tryVerConstraintParse ">= 1.0"
        >>= flip (flip testVerValidate $ SimpleVersion [1, 0, 1]) True
    tryVerConstraintParse "== 1.*"
        >>= flip (flip testVerValidate $ SimpleVersion [1, 0, 1]) True
    tryVerConstraintParse "/= 1.*"
        >>= flip (flip testVerValidate $ SimpleVersion [1, 0, 1]) False

test_parseFileOrNetworkPath :: IO ()
test_parseFileOrNetworkPath = do
    let f = testAnyCharParser parseFileOrNetworkPath
    f "/path/to/some" $ Left "/path/to/some"
    -- f ":/path/to/some" $ Right ("localhost", UnixSocket "/path/to/some")
    f "127.0.0.1:80" $ Right ("127.0.0.1", PortNumber (fromIntegral (80::Int)))
    f "127.0.0.1:www" $ Right ("127.0.0.1", Service "www")

test_parseSeconds :: IO ()
test_parseSeconds = do
    let f = testAnyCharParser parseSeconds
    f "10"          10
    f "10.1"        10.1
    f "1'20\""      80
    f "1'20.1\""    80.1
    f "1'20"        80
    f "1′20″"       80
    f "1′20"        80

testAnySafeCopy :: (SafeCopy a, Eq a, Show a) => a -> IO ()
testAnySafeCopy x = do
    let bs = runPut $ safePut x
    putStrLn $ C8.unpack $ B16.encode bs
    putStrLn $ show x
    case runGet safeGet bs of
        Left err -> do
                    putStrLn $ "FAIL: safeGet failed: " ++ err
                    putStrLn $ "      original value: " ++ show x
                    exitFailure
        Right x2 -> do
                    if x == x2
                        then
                            putStrLn $ "OK: "  ++ show x2
                        else do
                            putStrLn $ "FAIL: safeGet return different value: " ++ show x2
                            putStrLn $ "      original value: " ++ show x

data Dummy
type DummyId = KeyBackend Int Dummy
instance SafeCopy (KeyBackend Int Dummy) where
    putCopy = putCopyAnyId
    getCopy = getCopyAnyId

testSafeCopy :: IO ()
testSafeCopy = do
    testAnySafeCopy (FuzzyDayY 2014)
    testAnySafeCopy (SafeCopyId (Key (PersistInt64 1)) :: SafeCopyId Dummy)
    testAnySafeCopy (SafeCopyId (Key (PersistInt64 1134242)) :: SafeCopyId Dummy)
    testAnySafeCopy (SafeCopyId (Key (PersistInt64 113424224234)) :: SafeCopyId Dummy)


main :: IO ()
main = do
    -- testVerConstraint
    -- test_parseFileOrNetworkPath
    -- test_parseSeconds
    testSafeCopy
