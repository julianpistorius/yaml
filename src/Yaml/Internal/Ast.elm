module Yaml.Internal.Ast exposing (Ast, build)

{-|

@docs Ast, build

-}

import Char
import Parser exposing (..)
import Parser.LanguageKit as Parser exposing (..)
import Parser.LowLevel as Parser exposing (..)
import Set


{-| -}
type Ast
    = Primitive String
    | Hash (List ( String, Ast ))
    | Array (List Ast)


{-| -}
build : String -> Result Error Ast
build =
    run parser


parser : Parser Ast
parser =
    succeed identity
        |. beginning
        |= value



-- BEGINNING


beginning : Parser ()
beginning =
    oneOf
        [ documentNote |. spacesOrNewLines
        , spacesOrNewLines
        ]


documentNote : Parser ()
documentNote =
    threeDashes |. anythingUntilNewLine


threeDashes : Parser ()
threeDashes =
    ignore (Exactly 3) (\c -> c == '-')



-- VALUES


value : Parser Ast
value =
    lazy <|
        \() ->
            oneOf
                [ map Hash hashSingleLine
                , map Array arraySingleLine
                , map Primitive fieldName
                ]



-- SINGLE LINE HASHES


hashSingleLine : Parser (List ( String, Ast ))
hashSingleLine =
    lazy <|
        \() ->
            succeed identity
                |. symbol "{"
                |. spaces
                |= andThen (\n -> hashSingleLineHelp [ n ]) property
                |. spaces
                |. symbol "}"


hashSingleLineHelp : List ( String, Ast ) -> Parser (List ( String, Ast ))
hashSingleLineHelp revProperties =
    lazy <|
        \() ->
            oneOf
                [ andThen (\n -> hashSingleLineHelp (n :: revProperties)) hashPropertyNext
                , succeed (List.reverse revProperties)
                ]


hashPropertyNext : Parser ( String, Ast )
hashPropertyNext =
    lazy <|
        \() ->
            delayedCommit spaces <|
                succeed identity
                    |. symbol ","
                    |. spaces
                    |= property



-- SINGLE LINE ARRAY


arraySingleLine : Parser (List Ast)
arraySingleLine =
    lazy <|
        \() ->
            succeed identity
                |. symbol "["
                |. spaces
                |= andThen (\n -> arraySingleLineHelp [ n ]) value
                |. spaces
                |. symbol "]"


arraySingleLineHelp : List Ast -> Parser (List Ast)
arraySingleLineHelp revElements =
    lazy <|
        \() ->
            oneOf
                [ andThen (\n -> arraySingleLineHelp (n :: revElements)) arrayElementNext
                , succeed (List.reverse revElements)
                ]


arrayElementNext : Parser Ast
arrayElementNext =
    lazy <|
        \() ->
            delayedCommit spaces <|
                succeed identity
                    |. symbol ","
                    |. spaces
                    |= value



-- FIELD NAME


fieldName : Parser String
fieldName =
    variable (always True) isVarChar keywords


isVarChar : Char -> Bool
isVarChar char =
    Char.isLower char
        || Char.isUpper char
        || Char.isDigit char
        || (char == '_')


keywords : Set.Set String
keywords =
    Set.empty



-- PROPERTY


property : Parser ( String, Ast )
property =
    lazy <|
        \() ->
            succeed (,)
                |= fieldName
                |. spaces
                |. symbol ":"
                |. spaces
                |= value



-- GENERAL


spaces : Parser ()
spaces =
    ignore zeroOrMore (\c -> c == ' ')


spacesOrNewLines : Parser ()
spacesOrNewLines =
    ignore zeroOrMore (\c -> c == ' ' || String.fromChar c == "\n")


anythingUntilNewLine : Parser ()
anythingUntilNewLine =
    ignore zeroOrMore (\c -> c /= '\n')


whitespace : Parser ()
whitespace =
    Parser.whitespace
        { allowTabs = True
        , lineComment = LineComment "#"
        , multiComment = NoMultiComment
        }