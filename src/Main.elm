module Main exposing (ActiveView(..), Flags, KeyAction(..), Model, Msg(..), ThemeOption(..), WorkItem, body, dot, education, experience, feedback, footerItem, getMode, getNewTheme, getUrlFromKey, headerText, init, items, links, main, renderDescription, renderLinkItem, renderOptions, renderWorkItem, sectionTitle, subscriptions, summary, terminalContent, terminalFooter, terminalHeader, theme, topBar, update, view, welcome)

import Browser
import Browser.Dom as Dom
import Browser.Events exposing (onKeyDown)
import Browser.Navigation as Nav
import Html exposing (Html, a, div, h1, img, input, p, pre, span, text, textarea)
import Html.Attributes exposing (autofocus, class, classList, cols, href, id, placeholder, rows, src, style, tabindex, value)
import Html.Events exposing (on, onClick, onInput)
import Http
import Json.Decode as JD
import Json.Encode as JE
import Keyboard.Event exposing (KeyboardEvent, decodeKeyboardEvent)
import Ports
import Task
import Url
import Url.Builder exposing (absolute)

type alias Settings = 
    { theme : ThemeOption }

type alias Flags =
    { settings : Settings
    , apiUrl : String
    }

type alias FlagValues = 
    {
        theme : ThemeOption
        , apiUrl : String
    }

---- MODEL ----


type ActiveView
    = Welcome
    | Summary
    | Experience
    | Education
    | Links
    | Feedback
    | Language
    | Theme


type alias Model =
    { activeTheme : ThemeOption
    , inputText : String
    , key : Nav.Key
    , url : Url.Url
    , apiUrl : String
    , feedbackResult : String 
    }


getInitialValues : JD.Value -> FlagValues
getInitialValues values =
    let
        result =
            JD.decodeValue decodeFlags values
    in
    case result of
        Ok parsedValues ->
            {
                theme = parsedValues.settings.theme,
                apiUrl = parsedValues.apiUrl
            }

        Err e ->
            {
                theme = Classic,
                apiUrl = ""
            }

decodeFlags : JD.Decoder Flags
decodeFlags =
    JD.map2 Flags
        (JD.field "settings" settingsDecoder)
        (JD.field "apiUrl" JD.string)


settingsDecoder : JD.Decoder Settings
settingsDecoder =
    JD.map Settings (JD.field "theme" themeDecoder)
        
themeDecoder : JD.Decoder ThemeOption
themeDecoder =
    JD.string
    |> JD.andThen
            (\str ->
                case str of
                    "Classic" ->
                        JD.succeed Classic

                    "Green" ->
                        JD.succeed Green

                    somethingElse ->
                        JD.fail <| "Unknown theme: " ++ somethingElse
            )

init : JD.Value -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        values = getInitialValues flags
    in

    ( { key = key
      , url = url
      , activeTheme = values.theme
      , inputText = ""
      , apiUrl = values.apiUrl
      , feedbackResult = ""
      }
    , Dom.focus "outermost" |> Task.attempt (always NoOp)
    )



---- UPDATE ----


encodeThemeOption option =
    case option of
        Classic ->
            "Classic"

        Green ->
            "Green"


encodeSettings : Settings -> JE.Value
encodeSettings record =
    JE.object
        [ ( "theme", JE.string <| encodeThemeOption record.theme )
        ]


type KeyAction
    = ChangeTheme
    | ChangeView
    | FeedbackSubmit


type Msg
    = HandleKeyboardEvent KeyAction KeyboardEvent
    | HandleViewChange KeyboardEvent
    | HandleThemeInput KeyboardEvent
    | ThemeChange ThemeOption
    | TextInput String
    | NoOp
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | HandleFeedback KeyboardEvent
    | FeedbackPost ( Result Http.Error () )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        HandleKeyboardEvent action event ->
            let
                -- No matter what, we clear any feedback state on any keyboard input
                newModel = { model | feedbackResult = "" }
            in
        
            case action of
                ChangeTheme ->
                    update (HandleThemeInput event) newModel

                ChangeView ->
                    update (HandleViewChange event) newModel

                FeedbackSubmit ->
                    update (HandleFeedback event) newModel

        HandleViewChange event ->
            let
                newView =
                    getUrlFromKey event.ctrlKey event.key
            in
            case newView of
                Just v ->
                    ( model, Nav.pushUrl model.key v )

                Nothing ->
                    ( model, Cmd.none )

        TextInput input ->
            ( { model | inputText = input }, Cmd.none )

        ThemeChange newTheme ->
            ( { model | activeTheme = newTheme }, Cmd.none )

        HandleFeedback event ->
            let
                action = getActionFromKey event.ctrlKey event.key
            in
            case action of
                Submit ->
                    ( model, submitFeedback model.apiUrl model.inputText )
                Exit ->
                    ( { model | inputText = "" }, Nav.pushUrl model.key "/summary")
                Ignore ->
                    ( model, Cmd.none)


        HandleThemeInput event ->
            let
                newTheme =
                    getNewTheme event.ctrlKey event.key
            in
            case newTheme of
                Just t ->
                    let
                        newSettings =
                            { theme = t
                            }
                    in
                    ( { model | activeTheme = t }, Ports.storeSettings (encodeSettings newSettings) )

                Nothing ->
                    update (HandleViewChange event) model

        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | url = url }
            , Cmd.none
            )

        FeedbackPost response ->
            case response of
                Ok r ->
                    ( { model | inputText = "", feedbackResult = "Feedback submitted successfully." }, Nav.pushUrl model.key "/summary")
                Err error ->
                    ( { model | feedbackResult = "An unexpected error occurred." } , Cmd.none)

        NoOp ->
            ( model, Cmd.none )

type FeedbackAction = Submit | Exit | Ignore

getActionFromKey : Bool -> Maybe String -> FeedbackAction
getActionFromKey ctrl event =
    if not ctrl then
        Ignore
    else
        case event of 
            Just key ->
                case key of
                    "o" ->
                        Submit
                    "x" ->
                        Exit
                    _ ->
                        Ignore

            Nothing ->
                Ignore

getUrlFromKey : Bool -> Maybe String -> Maybe String
getUrlFromKey ctrl event =
    if not ctrl then
        Nothing

    else
        case event of
            Just key ->
                case key of
                    "s" ->
                        Just "/summary"

                    "w" ->
                        Just "/experience"

                    "e" ->
                        Just "/education"

                    "f" ->
                        Just "/feedback"

                    "z" ->
                        Just "/language"

                    "t" ->
                        Just "/theme"

                    "l" ->
                        Just "/links"

                    _ ->
                        Nothing

            Nothing ->
                Nothing


getNewTheme : Bool -> Maybe String -> Maybe ThemeOption
getNewTheme ctrl event =
    if ctrl then
        Nothing

    else
        case event of
            Just key ->
                case key of
                    "1" ->
                        Just Classic

                    "2" ->
                        Just Green

                    _ ->
                        Nothing

            Nothing ->
                Nothing

feedbackRequestEncoder : String -> JE.Value
feedbackRequestEncoder str = JE.object [ ( "feedback", JE.string str ) ]

submitFeedback : String -> String -> Cmd Msg
submitFeedback url str =
    Http.post {
        url=url,
        body=( Http.jsonBody <| feedbackRequestEncoder str ),
        expect= Http.expectWhatever FeedbackPost 
    }

---- VIEW ----


view : Model -> Browser.Document Msg
view model =
    { title = "Jared"
    , body =
        [ div []
            [ div [ class "h-screen w-screen" ]
                [ topBar
                , body model
                ]
            ]
        ]
    }


topBar =
    div [ class "flex flex-row items-center justify-start topbar bg-grey-darkest" ]
        [ div [ class "flex flex-row items-center justify-center pl-2" ]
            [ dot "bg-red-light"
            , dot "bg-yellow"
            , dot "bg-green"
            ]
        ]


dot : String -> Html Msg
dot color =
    div
        [ classList
            [ ( color, True )
            , ( "dot", True )
            , ( "m-1", True )
            ]
        ]
        []


body model =
    div [ class "terminal bg-black h-full" ] [ terminalHeader model.url.path model.activeTheme, div [ class "terminal-content" ] [ terminalContent model ], terminalFooter model.url.path model.activeTheme model.feedbackResult ]


terminalContent model =
    let
        themeClasses =
            case model.activeTheme of
                Classic ->
                    " text-white h-full"

                Green ->
                    " green-theme-text h-full"
    in
    div [ class themeClasses ]
        [ case model.url.path of
            "/" ->
                welcome model

            "/summary" ->
                summary

            "/education" ->
                education

            "/experience" ->
                experience

            "/links" ->
                links

            "/feedback" ->
                feedback model

            "/theme" ->
                theme model.activeTheme

            _ ->
                text "Section coming soon"
        ]


terminalFooter : String -> ThemeOption -> String ->  Html Msg
terminalFooter terminalView currentTheme feedbackResult =
    let
        footer =
            footerItem currentTheme
        footerLinks =
            case terminalView of
                    "/feedback" ->
                        div [ class "flex flex-row flex-nowrap justify-start" ]
                            [
                                footer "^X" "Exit" "/summary"
                            ,   footer "^O" "WriteOut (Submit Feedback)" "/summary"
                            ]
                        
                    _ ->
                        div [ class "flex flex-row flex-nowrap justify-between" ]
                            [ footer "^S" "Summary" "/summary"
                            , footer "^W" "Work Experience" "/experience"
                            , footer "^E" "Education" "/education"
                            , footer "^L" "Links" "/links"
                            , footer "^F" "Leave feedback" "/feedback"
                            , footer "^Z" "Change Language" "/language"
                            , footer "^T" "Change Theme" "/theme"
                            ]

    in
    div [ class "terminal-footer" ] [
        if feedbackResult /= "" then span [class ("bg-grey-light text-black w-auto p-1")] [text ("[ " ++ feedbackResult ++ " ]")] else div [] []
        , footerLinks
        ]


terminalHeader url activeTheme =
    let
        themeClasses =
            case activeTheme of
                Classic ->
                    " bg-grey-light"

                Green ->
                    " green-background"
    in
    div [ class "terminal-header" ]
        [ div [ class ("w-full flex flex-row items-center justify-start p-1" ++ themeClasses) ]
            [ p [ class "w-1/3 flex justify-start" ] [ text "JSK resume 1.0.0" ]
            , p [ class "w-2/3 flex justify-start" ]
                [ text
                    (if url /= "/" then
                        "File: " ++ headerText url

                     else
                        headerText url
                    )
                ]
            ]
        ]


headerText : String -> String
headerText currentView =
    case currentView of
        "/summary" ->
            "summary.txt"

        "/education" ->
            "education.txt"

        "/experience" ->
            "work_experience.txt"

        "/feedback" ->
            "feedback_form.txt"

        "/theme" ->
            "theme.txt"

        "/language" ->
            "language_select.txt"

        "/" ->
            "New Buffer"

        "/links" ->
            "links.txt"

        _ ->
            "unknown.txt"


footerItem : ThemeOption -> String -> String -> String -> Html Msg
footerItem currentTheme key description path =
    let
        keyClasses =
            case currentTheme of
                Classic ->
                    "m-1 bg-grey-light text-black"

                Green ->
                    "m-1 green-background text-black"

        descClasses =
            case currentTheme of
                Classic ->
                    "m-1 text-white"

                Green ->
                    "m-1 green-theme-text"
    in
    a [ class "flex flex-row p-1 footer-link", href path ]
        [ p [ class keyClasses ] [ text key ]
        , p [ class descClasses ] [ text description ]
        ]



--- DISPLAY SECTIONS ---


sectionTitle : String -> Html Msg
sectionTitle title =
    p [ class "text-2xl w-48" ] [ text title ]


summary =
    div [ class "text-left ml-2 body-text" ]
        [ p [] [ text "Jared Kobos" ]
        , p [] [ text "JavaScript Developer at Linode" ]
        , p [] [ text "Build things with React, Redux, Jest, Typescript, and Gatsby. Also a fan of Elm, Go, and Python." ]
        ]


education =
    div [ class "text-left ml-2 body-text flex flex-col justify-between h-full" ]
        [ div []
            [ sectionTitle "Education"
            , p [] [ text "Bachelor of Music Education (University of Delaware)" ]
            , p [] [ text "Master of Music (Florida State University)" ]
            , p [] [ text "Doctor of Musical Arts* (Michigan State University)" ]
            ]
        , div []
            [ p [ class "text-right" ] [ text "* (it's a long story)" ]
            ]
        ]


type alias WorkItem =
    { company : String
    , position : String
    , location : String
    , start : String
    , end : String
    , description : List String
    }


items =
    [ WorkItem "Linode"
        "JavaScript Developer"
        "Philadelphia, PA"
        "05-01-18"
        ""
        [ "Build and maintain features for front end applications"
        , "Research and implement patterns to improve the codebase"
        ]
    , WorkItem "Linode"
        "Technical Writer"
        "Philadelphia, PA"
        "09-06-17"
        "05-01-18"
        [ "Write, edit, and tech edit documentation on Linux-related topics"
        , "Use continuous integration and scripting to improve quality of documentation library"
        ]
    , WorkItem "EF Education First"
        "Content Writer"
        "Shanghai, CN"
        "02-04-16"
        "08-21-17"
        [ "Write textbook and online content for an international education company"
        ]
    , WorkItem "EF Education First"
        "International Teacher"
        "Shanghai, CN"
        "07-18-13"
        "02-04-16"
        [ "Teach English to Chinese kids"
        ]
    ]


experience =
    div [ class "text-left ml-2 body-text" ]
        [ sectionTitle "Work Experience"
        , div [] (List.map renderWorkItem items)
        ]


renderWorkItem : WorkItem -> Html Msg
renderWorkItem item =
    let
        dates =
            if item.end == "" then
                item.start ++ " - Present"

            else
                item.start ++ " - " ++ item.end
    in
    div [ class "mt-6" ]
        [ p [ class "leading-tight w-full flex flex-row justify-between" ]
            [ span [] [ text (item.position ++ "  :  " ++ (item.company ++ " (" ++ item.location ++ ")")) ]
            , span [ class "mr-6" ] [ text dates ]
            ]
        , div [ class "leading-normal" ] (List.map renderDescription item.description)
        ]


renderDescription : String -> Html Msg
renderDescription desc =
    p [] [ text (" - " ++ desc) ]


links =
    div [ class "text-left ml-2 body-text" ]
        [ sectionTitle "Links"
        , renderLinkItem "https://github.com/linode/manager" "Current open-source work project"
        , renderLinkItem "https://github.com/jskobos/elm-terminal-resume" "This site's source code"
        , renderLinkItem "https://github.com/jskobos" "GitHub Profile"
        ]


renderLinkItem url description =
    p [ class "mt-6 ml-4" ] [ a [ href url, class "link-item" ] [ text description ] ]


welcome model =
    div [ class "flex flex-column justify-start w-full" ]
        [ text ""
        ]


feedback model =
    div [ class "flex flex-col justify-start align-center ml-2 text-left body-text" ]
        [ 
          sectionTitle "Leave Feedback"
        , textarea [ autofocus True, value model.inputText, onInput TextInput, class "bg-black text-white text-left w-full h-full" ] []
        ]


type ThemeOption
    = Classic
    | Green


theme : ThemeOption -> Html Msg
theme activeTheme =
    div [ class "text-left ml-2 body-text" ]
        [ sectionTitle "Choose a Theme"
        , renderOptions activeTheme
        ]


renderOptions activeTheme =
    div [ class "m-2" ]
        [ div [ class "p-2 flex flex-row justify-start" ]
            [ div [ class "mr-2" ] [ text "1: " ]
            , div [] [ text "Normal" ]
            ]
        , div [ class "p-2 flex flex-row justify-start" ]
            [ div [ class "mr-2" ] [ text "2: " ]
            , div [] [ text "Green" ]
            ]
        ]



---- SUBSCRIPTIONS ----


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        mode =
            getMode model.url.path
    in
    onKeyDown (JD.map (HandleKeyboardEvent mode) decodeKeyboardEvent)


getMode v =
    case v of
        "/theme" ->
            ChangeTheme

        "/feedback" ->
            FeedbackSubmit

        _ ->
            ChangeView



---- PROGRAM ----


main : Program JD.Value Model Msg
main =
    Browser.application
        { view = view
        , init = init
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }
