{-# LANGUAGE OverloadedStrings #-}
import           Data.Maybe
import           Data.Monoid
import           Hakyll
import           Text.Pandoc.Options

--------------------------------------------------------------------------------
hakyllConf :: Configuration
hakyllConf = defaultConfiguration { deployCommand = "bash deploy.sh" }

myFeedConfiguration :: FeedConfiguration
myFeedConfiguration = FeedConfiguration
    { feedTitle       = "joomy's blog"
    , feedDescription = "A blog about computer science and functional programming."
    , feedAuthorName  = "Joomy Korkut"
    , feedAuthorEmail = "joomy@type.systems"
    , feedRoot        = "http://joomy.korkutblech.com"
    }

main :: IO ()
main = hakyllWith hakyllConf $ do
    match "assets/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "pages/*" $ do
        route   $ setExtension "html"
        compile $ customPandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls

    match "pages/poems/*" $ do
        route   $ setExtension "html"
        compile $ customPandocCompiler
            >>= loadAndApplyTemplate "templates/page.html" defaultContext
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls

    tags <- buildTags "posts/*" (fromCapture "tags/*.html")
    match "posts/*" $ do
        route $ setExtension "html"
        compile $ customPandocCompiler
            >>= loadAndApplyTemplate "templates/post.html" (postCtx tags)
            >>= saveSnapshot "post-content"
            >>= loadAndApplyTemplate "templates/default.html" (postCtx tags)
            >>= relativizeUrls
    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAllSnapshots "posts/*" "post-content"
            let archiveCtx =
                    listField "posts" (postCtx tags) (return posts) <>
                    constField "title" "Archives" <>
                    defaultContext
            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls
    -- Post tags
    -- A page for each tag
    tagsRules tags $ \tag pattern -> do
        let title = "Posts tagged " ++ tag
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll pattern
            let ctx = constField "title" title <>
                        listField "posts" (postCtx tags) (return posts) <>
                        defaultContext
            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

    -- Turkish posts
    etiket <- buildTags "yazilar/*" (fromCapture "etiket/*.html")
    match "yazilar/*" $ do
        route $ setExtension "html"
        compile $ customPandocCompiler
            >>= loadAndApplyTemplate "templates/yazi.html" (postCtx etiket)
            >>= saveSnapshot "post-content"
            >>= loadAndApplyTemplate "templates/default.html" (postCtx etiket)
            >>= relativizeUrls
    create ["arsiv.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAllSnapshots "yazilar/*" "post-content"
            let archiveCtx =
                    listField "yazilar" (postCtx etiket) (return posts) <>
                    constField "title" "Arşiv" <>
                    defaultContext
            makeItem ""
                >>= loadAndApplyTemplate "templates/arsiv.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls
    -- Turkish tags
    tagsRules etiket $ \tag pattern -> do
        let title = "Posts tagged " ++ tag
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll pattern
            let ctx = constField "title" title <>
                        listField "yazilar" (postCtx etiket) (return posts) <>
                        defaultContext
            makeItem ""
                >>= loadAndApplyTemplate "templates/arsiv.html" ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

    -- Index
    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- fmap (take 3) . recentFirst =<< loadAll "posts/*"
            yazilar <- fmap (take 3) . recentFirst =<< loadAll "yazilar/*"
            let indexContext =
                    listField "posts" (postCtx tags) (return posts) <>
                    field "tags" (\_ -> renderTagList tags) <>
                    listField "yazilar" (postCtx etiket) (return yazilar) <>
                    field "etiketler" (\_ -> renderTagList etiket) <>
                    defaultContext
            getResourceBody
                >>= applyAsTemplate indexContext
                >>= loadAndApplyTemplate "templates/default.html" indexContext
                >>= relativizeUrls

    match "templates/*" $ compile templateCompiler

    create ["atom.xml"] $ do
        route idRoute
        compile $ do
            let feedCtx = (postCtx tags) <> bodyField "description"
            posts <- fmap (take 10) . recentFirst =<<
                loadAllSnapshots "posts/*" "post-content"
            renderAtom myFeedConfiguration feedCtx posts
    create ["atom-tr.xml"] $ do
        route idRoute
        compile $ do
            let feedCtx = (postCtx tags) <> bodyField "description"
            posts <- fmap (take 10) . recentFirst =<<
                loadAllSnapshots "yazilar/*" "post-content"
            renderAtom myFeedConfiguration feedCtx posts

--------------------------------------------------------------------------------
postCtx :: Tags -> Context String
postCtx tags = mconcat
    [ modificationTimeField "mtime" "%U"
    , dateField "date" "%B %e, %Y"
    , tagsField "tags" tags
    , defaultContext
    ]

customPandocCompiler :: Compiler (Item String)
customPandocCompiler =
    let customExtensions = [Ext_footnotes, Ext_autolink_bare_uris]
        defaultExtensions = writerExtensions defaultHakyllWriterOptions
        newExtensions = foldr enableExtension defaultExtensions customExtensions
        writerOptions = defaultHakyllWriterOptions {
                          writerExtensions = newExtensions
                        }
    in pandocCompilerWith defaultHakyllReaderOptions writerOptions
