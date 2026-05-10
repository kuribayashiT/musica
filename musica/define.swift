//
//  define.swift
//  musica
//
//  Created by 栗林貴大 on 2017/05/26.
//  Copyright © 2017年 K.T. All rights reserved.
//

import Foundation
import UIKit
import MediaPlayer
import AVFoundation
import CoreData
import GoogleMobileAds

/*----------------------------------------------------------------
 ビルドモード debug : true/ release : false
 ----------------------------------------------------------------*/
let DEBUG_FLG = false
let TEST_DEVICE_iPHPNEX = "e5b4ae33cfffdd83fbfa7c7a3215a642"
var LOG_TEXT = ""

/*----------------------------------------------------------------
  課金モード debug : true/ release : false
 ----------------------------------------------------------------*/
var KAKIN_FLG = false
var KAKINPLICE_PLICE = "a"
/// App Store から取得したフォーマット済み価格文字列（例: "¥250"）
var KAKIN_PRICE_STRING = ""
let SECRET_CODE = "cdfd1d9d44ea42b5848546d039d9d182"
let MySoftwareRestartNotification = Notification.Name("MySoftwareRestartNotification")

/*----------------------------------------------------------------
 全般
 ----------------------------------------------------------------*/
/*
 tabアニメーション
 */
var START_APP_TAB = 0
enum tabAnimationType: String {
    case move
    case fade
    case scale
    case custom
    static var all: [tabAnimationType] = [.move, .scale, .fade, .custom]
}
let tabBarItemColor :[UIColor] = [UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0),
                                  UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0),
                                  UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0),
                                  UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)]
var TAB_MOVE_FLG = true
/*
 カラーテーマ
 */
var NOW_COLOR_THEMA = 5
var COLOR_THEMA_NAME = [
    localText(key:"design_theme_old"),
    localText(key:"design_theme_pop"),
    localText(key:"design_theme_popred"),
    localText(key:"design_theme_sharpblue"),
    localText(key:"design_theme_sharpred"),
    localText(key:"design_theme_sharpnomal"),
    localText(key:"design_theme_sharpdark"),
    localText(key:"design_theme_sharpblack"),
    localText(key:"design_theme_now")
]
/*----------------------------------------------------------------
 色
 ----------------------------------------------------------------*/
let LIGHT_BLUE = UIColor.systemBlue
let LIGHT_DARKBLUE = UIColor(red: 0/255, green: 77/255, blue: 128/255, alpha: 255/255)
let LIGHT_GREEN = UIColor(red: 0/255, green: 175/255, blue: 128/255, alpha: 255/255)
let LIGHT_DARKRED = UIColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1.0)
let LIGHT_DARK = UIColor(red: 66/255, green: 66/255, blue: 66/255, alpha: 255/255)
let LIGHT_GRAY = UIColor(red: 235/255, green: 235/255, blue: 235/255, alpha: 255/255)
let LIGHT_LIGHT_GREEN = UIColor(red: 0/255, green: 200/255, blue: 128/255, alpha: 255/255)
let LIGHT_ORANGE = UIColor(red: 255/255, green: 147/255, blue: 0/255, alpha: 255/255)
let BLACK = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
enum COLOR_THEMA: Int {
    case HOME = 0
    case RANKING = 1
    case SEARCH = 2
    case SCAN = 3
    case SETTING = 4
}
enum NAVIGATION_COLOR_SETTINGS: Int {
//    case DEFAULT = 0
//    case POP = 1
//    case POP_RED = 2
//    case SHARP_WHITE_BLUE = 3
//    case SHARP_WHITE_RED = 4
//    case SHARP_NOMAL = 5
//    case SHARP_DARK = 6
//    case SHARP_BLACK = 7
//    case IMADOKI = 8
    case DEFAULT = 0
    case POP = 1
    case WHITE_BLUE = 2
    case WHITE_DARK_BLACK = 3
    case WHITE_DARK_BLUE = 4
    case WHITE_DARK_RED = 5
    case BLACK = 6
    case DARK_BLUE = 7
    case DARK_RED = 8
}
// ナビゲーションバー
let NAVIGATION_COLOR:[[UIColor]] = [
    // デフォルトカラー
    [UIColor(red: 0.2, green: 0.1, blue: 0.0, alpha: 1.0),
     UIColor(red: 0.0, green: 0.0, blue: 0.4, alpha: 1.0),
     UIColor(red: 0.7, green: 0.0, blue: 0.0, alpha: 1.0),
     UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0),
     UIColor(red: 0.0, green: 0.2, blue: 0.0, alpha: 1.0)],
    // ポップ
    [UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0),
     UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0),
     UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0),
     UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0),
     UIColor(red: 0.0, green: 0.6, blue: 0.4, alpha: 1.0)],
    // シャープ（白と青っぽい）
    [darkModeNaviWhiteUIcolor(),
     darkModeNaviWhiteUIcolor(),
     darkModeNaviWhiteUIcolor(),
     darkModeNaviWhiteUIcolor(),
     darkModeNaviWhiteUIcolor()],
    // シャープ（白と黒）
    [darkModeNaviWhiteUIcolor(),
     darkModeNaviWhiteUIcolor(),
     darkModeNaviWhiteUIcolor(),
     darkModeNaviWhiteUIcolor(),
     darkModeNaviWhiteUIcolor()],
    // シャープ（白とダークブルー）
    [darkModeNaviWhiteUIcolor(),
     darkModeNaviWhiteUIcolor(),
     darkModeNaviWhiteUIcolor(),
     darkModeNaviWhiteUIcolor(),
     darkModeNaviWhiteUIcolor()],
    // シャープ（白とダークレッド）
    [darkModeNaviWhiteUIcolor(),
     darkModeNaviWhiteUIcolor(),
     darkModeNaviWhiteUIcolor(),
     darkModeNaviWhiteUIcolor(),
     darkModeNaviWhiteUIcolor()],
    // ダークブルー
    [LIGHT_DARKBLUE,
     LIGHT_DARKBLUE,
     LIGHT_DARKBLUE,
     LIGHT_DARKBLUE,
     LIGHT_DARKBLUE],
    // ブラック
    [BLACK,
     BLACK,
     BLACK,
     BLACK,
     BLACK],
    // ダークレッド
    [LIGHT_DARKRED,
     LIGHT_DARKRED,
     LIGHT_DARKRED,
     LIGHT_DARKRED,
     LIGHT_DARKRED]
]
let NAVIGATION_TEXT_COLOR:[[UIColor]] = [
    // デフォルトカラー 対応文字色
    [UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)],
    // ポップ 対応文字色
    [UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)],
    // シャープ（白と青っぽい）対応ボタン色
    [LIGHT_BLUE,
     LIGHT_BLUE,
     LIGHT_BLUE,
     LIGHT_BLUE,
     LIGHT_BLUE],
    // シャープ（白と黒）対応文字色
    [darkModeLabelColor(),
     darkModeLabelColor(),
     darkModeLabelColor(),
     darkModeLabelColor(),
     darkModeLabelColor()],
    // シャープ（白とダークブルー）対応文字色
    [LIGHT_DARKBLUE,
     LIGHT_DARKBLUE,
     LIGHT_DARKBLUE,
     LIGHT_DARKBLUE,
     LIGHT_DARKBLUE],
    // シャープ（白とダークレッド）対応ボタン色
    [LIGHT_DARKRED,
     LIGHT_DARKRED,
     LIGHT_DARKRED,
     LIGHT_DARKRED,
     LIGHT_DARKRED],
    // ダークブルー　対応文字色
    [UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)],
    // ブラック　対応文字色
    [UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)],
    // ダークレッド
    [UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)]
]
let NAVIGATION_BTN_COLOR:[[UIColor]] = [
    // デフォルトカラー 対応ボタン色
    [UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)],
    // ポップ 対応ボタン色
    [UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)],
    // シャープ（白と青っぽい）対応ボタン色
    [LIGHT_BLUE,
     LIGHT_BLUE,
     LIGHT_BLUE,
     LIGHT_BLUE,
     LIGHT_BLUE],
    // シャープ（白と黒）対応ボタン色
    [darkModeIconBlackUIcolor(),
    darkModeIconBlackUIcolor(),
    darkModeIconBlackUIcolor(),
    darkModeIconBlackUIcolor(),
    darkModeIconBlackUIcolor()],
    // シャープ（白とダークブルー）対応ボタン色
    [LIGHT_DARKBLUE,
     LIGHT_DARKBLUE,
     LIGHT_DARKBLUE,
     LIGHT_DARKBLUE,
     LIGHT_DARKBLUE],
    // シャープ（白とダークレッド）対応ボタン色
    [LIGHT_DARKRED,
     LIGHT_DARKRED,
     LIGHT_DARKRED,
     LIGHT_DARKRED,
     LIGHT_DARKRED],
    // ダークブルー　対応ボタン色
    [UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)],
    // ブラック　対応ボタン色
    [UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)],
    // ダークレッド
    [UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)]
]
// PTR時のくるくるの色
let NAVIGATION_PTR_COLOR:[[UIColor]] = [
    // デフォルトカラー 対応くるくるの色
    [UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 0.5),
     UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.5),
     UIColor.lightGray,
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)],
    // シャープ（白と黒）対応くるくるの色
    [UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 0.5),
     UIColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 0.5),
     UIColor.lightGray,
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
     UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)],
    // シャープ（白と青っぽい）対応くるくるの色
    [LIGHT_BLUE,
     LIGHT_BLUE,
     LIGHT_BLUE,
     LIGHT_BLUE,
     LIGHT_BLUE],
    // シャープ（白と黒）対応くるくるの色
    [BLACK,
     BLACK,
     BLACK,
     BLACK,
     BLACK],
    // シャープ（白とダークブルー）対応くるくるの色
    [LIGHT_DARKBLUE,
     LIGHT_DARKBLUE,
     LIGHT_DARKBLUE,
     LIGHT_DARKBLUE,
     LIGHT_DARKBLUE],
    // シャープ（白と赤っぽい）対応くるくるの色
    [LIGHT_DARKRED,
     LIGHT_DARKRED,
     LIGHT_DARKRED,
     LIGHT_DARKRED,
     LIGHT_DARKRED],
    // ブラック　対応ボタン色
    [UIColor.lightGray,
     UIColor.lightGray,
     UIColor.lightGray,
     UIColor.lightGray,
     UIColor.lightGray],
    // ダークブルー　対応くるくるの色
    [LIGHT_DARKBLUE,
     LIGHT_DARKBLUE,
     UIColor.lightGray,
     LIGHT_DARKBLUE,
     LIGHT_DARKBLUE],
    // ダークレッド
    [LIGHT_DARKRED,
     LIGHT_DARKRED,
     UIColor.lightGray,
     LIGHT_DARKRED,
     LIGHT_DARKRED]
]
/*
 画像系
 */
let playBtnImage = UIImage(named: "arrow_triangle-right")!.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
let stopBtnImage = UIImage(named: "icon_pause")!.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
let playBtnLImage = UIImage(named: "saisei")!.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
let stopBtnLImage = UIImage(named: "teishi")!.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
let playBackBtnImage = UIImage(named: "arrow_carrot-2left")!.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
let playNextBtnImage = UIImage(named: "arrow_carrot-2right")!.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
let playBackLBtnImage = UIImage(named: "modoru")!.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
let playNextLBtnImage = UIImage(named: "susumu")!.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
let goodImage = UIImage(named: "icon_like")

// 選択する色
let colorChoicesNameArray = ["white","darkGray","lightGray","black","gray",
                             "red","green","blue","cyan","yellow",
                             "magenta","orange","purple","brown","clear"]

// 画像の表示調整
let ICON_CORNER_RADIUS_SETTINMGS : CGFloat = 10.0
let ICON_CORNER_RADIUS_SETTINMGS_THIN : CGFloat = 4.0
let ICON_BORDERWIDTH : CGFloat = 0
let ICON_BORDERWIDTH_THIN : CGFloat = 1.5

// HELPボタン
var HOME_HELP_BTN_DISPLAY_FLG = true

/*
 tableViewの高さ
 */
let CELL_ROW_HEIGT_THICK = CGFloat(94)
let CELL_ROW_HEIGT_MIDDLE : Int = 54
let CELL_ROW_HEIGT_THIN : Int = 44
var adViewHeight = CGFloat(90)

// ステータスバーの高さ
let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
//@available(iOS 13.0, *)
//let statusBarHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
let statusBarHeight: CGFloat = UIApplication.shared.statusBarFrame.height
// ナビゲーションバーの高さ
let navigationBarHeight = UINavigationController().navigationBar.frame.size.height
/*----------------------------------------------------------------
 音楽Player周りの変数/定数
 ----------------------------------------------------------------*/
// カスタムライブラリ遷移元フラグ
var CUSTOM_LYBRARY_FROM_MUSICLIST = false
var CUSTOM_LYBRARY_FLG = false
var CUSTOM_LYBRARY_NAME = ""
var changeTrackList:[TrackData] = []
// 歌詞表示状態
var LYRIC_IMG_SEGMENT_STATE = 0
// 音楽再生関連の定数/変数
var audioPlayer: HighSpeedAudioPlayer!
var audioTestPlayer:AVAudioPlayer!
var defaultCenter = MPNowPlayingInfoCenter.default()
let NOW_NOT_PLAYING = -1
let NOW_NONE_MUSICLIBRARY_CODE = -1
var newSelectPlayNum : Int = 0
var returnEditFlg = false

var commandCenter = MPRemoteCommandCenter.shared();

//trackデータの構造体を定義する。
struct TrackData {
    var title : String = ""
    var artist : String = ""
    var albumName : String = ""
    var albumArtistName : String = ""
    var genre : String = ""
    var url : URL? = nil
    var lyric : String = ""
    var existFlg : Bool = false
    var checkedFlg : Bool = false
    var artworkImg : UIImage? = nil
    var isCloudItem : Bool = true
}

//albumデータの構造体を定義する。
struct AlbumData {
    var title : String? = ""
    var artist : String? = ""
    var artwork : MPMediaItemArtwork? = nil
    var trackNum : Int = 0
    var existFlg : Bool = false
    var checkedFlg : Bool = false
    var trackData : [TrackData] = []
}

struct NowPlayingData {
    var musicLibraryCode : Int = NOW_NONE_MUSICLIBRARY_CODE
    var nowPlayingLibrary : String = ""
    var nowPlaying : Int = NOW_NOT_PLAYING
    var trackData : [TrackData] = []
    var trackDataShuffled : [TrackData] = []
}

var selectedTracks:[String:Bool]=[String:Bool]()
var playingMusicLabraryTracks:[String:Bool]=[String:Bool]()
var playingTestTracks:[Int:Bool]=[Int:Bool]()

var NowPlayingMusicLibraryData : NowPlayingData = NowPlayingData()
var displayMusicLibraryData : NowPlayingData = NowPlayingData()

// 音楽再生設定値
var selectMusicLibraryTrackNum : Int = 0
var SHUFFLE_FLG : Bool = false
var SHUFFLE_MV_FLG : Bool = false
var SHUFFLE_CHANGE_ON_FLG : Bool = false
var SHUFFLE_CHANGE_OFF_FLG : Bool = false
let REPEAT_STATE_NONE: Int = 0
let REPEAT_STATE_ONE: Int = 1
let REPEAT_STATE_ALL: Int = 2
var repeatState = 0
var repeatMVState = 0
var NEXT_TAP_FLG : Bool = false
var volume : Float = 1.0
var speedRow : Int = 5
let speedList = [0.5,0.6,0.7,0.8,0.9,1.0,
                1.1,1.2,1.3,1.4,1.5,1.6,1.7,1.8,1.9,2.0,
                2.1,2.2,2.3,2.4,2.5,2.6,2.7,2.8,2.9,3.0,
                3.1,3.2,3.3,3.4,3.5,3.6,3.7,3.8,3.9,4.0,
                4.1,4.2,4.3,4.4,4.5,4.6,4.7,4.8,4.9,5.0,
                5.1,5.2,5.3,5.4,5.5,5.6,5.7,5.8,5.9,6.0,
                6.1,6.2,6.3,6.4,6.5,6.6,6.7,6.8,6.9,7.0,
                7.1,7.2,7.3,7.4,7.5,8.0,10.0,15.0,20.0,30.0,40.0,50.0
]

var mvSpeedRow : Int = 5
var mvSpeedList : [Float] = [0.25,0.5,0.6,0.75,0.9,1.0,1.25,1.5,2.0,2.5,3.0]
let NEXT = true
let PREV = false
/*----------------------------------------------------------------
 Youtube Player周りの変数/定数
 ----------------------------------------------------------------*/
 var YOUTUBE_PLAYER_FLG = true
 var nowRate : Float = 1.0
 var NOW_PLAYING_MV = -1
 var PLAY_MV_NUM_IN_PLAYLIST = 0
 var _videpID = ""
var PlayerViewControllerAddFlg = false
// Rate State
enum YoutubeRateMsgType: Int {
    case SUCCESS = 0
    case FAILURE = 1
    case INCOMPATIBLE = 2
    case DEBUG = 3
}
// Play Result
enum YoutubeMvPlayResult: Int {
    case SUCCESS = 0
    case WAIT = 1
    case TIMEOUT = 2
    case UNPLAY_VIDEO = 3
    case MOVE_VIEW = 4
}

var MV_SORT_ORDER_EDIT_FLG = false
/*----------------------------------------------------------------
 設定画面の定数
 ----------------------------------------------------------------*/
let FIRST_ACTIVATION_FLG = true

let SETTING : String = localText(key:"setting")
let OSUSUME : String = localText(key:"setting_recommend_app")
let HELP : String = localText(key:"setting_help")
let WHAT_AD : String = localText(key:"setting_about_ad")
let ABOUT_APP : String = localText(key:"setting_about_app")
let SPONSOR_AD : String = localText(key:"setting_ad")

// アプリについて
let APP_NAME : String = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)!
let APP_INFO : String = localText(key:"setting_about_app")
let SHOW_LOG : String = localText(key:"debug_log")
let SHOW_KANRI : String = localText(key:"app_management")
let OPEN_SOURCE_LICENSE : String = localText(key:"app_oss")
let APP_REVIEW : String = localText(key:"app_review")
let INTRODUCING_APP_FRIENDS : String = localText(key:"app_introduction")

// おすすめアプリ
let TODOLIST : String = localText(key:"recommended_app_todolist")
let SCANCAMERA : String = localText(key:"recommended_app_scancamera")
let MR_STICK : String = localText(key:"recommended_app_mr_stick")
let NANOPITA : String = localText(key:"recommended_app_nanopita")

// ヘルプ
var site = HOW_TO_USE
let HOW_TO_USE : String = localText(key:"homepage_musicahoutouse")
let HOMEPAGE_TITLE : String = localText(key:"homepage_musica")
let PP_TITLE : String = localText(key:"homepage_pp")
let HOMEPAGE : String = localText(key:"to_homepage_musica")
let DRM : String = localText(key:"musictrack_howto_drm")
let FAQ : String = localText(key:"qa")
let IMPROVEMENT_REQUEST_SENT : String = localText(key:"qa_request")
let INQUIRY_VIOLATION_REPORT : String = localText(key:"qa_report")

// 設定項目
let LOCAL_PUSH_RANKING_ID = "pushID_ranking"
let SETTING_CONTENTS_NUM : String = localText(key:"setting_item_resultnum")
let SETTING_CONTENTS_NUM_EXPLANATION: String = localText(key:"setting_item_resultnum_des")
let SETTING_HELP_FLAG : String = localText(key:"setting_item_help_des")
let SETTING_CHASH_CLEAR : String = localText(key:"setting_item_cashclear")
let SETTING_CHASH_CLEAR_EXPLANATION : String = localText(key:"setting_item_cashclear_des")
let SETTING_AD_CLEAR_TITLE : String = localText(key:"setting_item_adclear")
let SETTING_AD_CLEAR_MASAGE : String = localText(key:"setting_item_adclear_des")
let SETTING_CHASH_CLEAR_TITLE : String = localText(key:"setting_item_cashclear_alert")
let SETTING_CHASH_CLEAR_MASAGE : String = localText(key:"setting_item_cashclear_alert_des")
let SETTING_HELP_FLAG_EXPLANATION: String = localText(key:"setting_item_helpappear")
let SETTING_PUSH : String = localText(key:"setting_item_push")
let REMOVE_AD : String = localText(key:"setting_item_adclear")
let REMOVED_AD : String = localText(key:"setting_item_kakinkaijo")
let SETTING_DEZAIN : String = localText(key:"setting_item_design")

var settingSectionTitle = [SETTING,WHAT_AD, ABOUT_APP, OSUSUME]
let settingSectionTitle_mukakin = [SETTING,WHAT_AD, ABOUT_APP, OSUSUME]
let settingSectionTitle_kakin = [SETTING,OSUSUME,ABOUT_APP]
let settingSectionAppInfo = [(HOW_TO_USE,""),(INTRODUCING_APP_FRIENDS,""),(IMPROVEMENT_REQUEST_SENT,""),(INQUIRY_VIOLATION_REPORT,""),(APP_INFO,""),(HOMEPAGE,"")]

let settingSectionSetting = [(SETTING_PUSH,"")]
let settingSectionRemoveAD = [(REMOVE_AD,"")]
let settingSectionRemovedAD = [(REMOVED_AD,"")]
let settingSectionSetting_dev = [(SETTING_PUSH,""),(SHOW_LOG,""),(SHOW_KANRI,"")]
let settingSectionApp = [
    [
        localText(key:"recommended_app_scancamera"),
        localText(key:"recommended_app_scancamera_title"),
        localText(key:"recommended_app_scancamera_des")
    ],
    [
        localText(key:"recommended_app_todolist"),
        localText(key:"recommended_app_todolist_title"),
        localText(key:"recommended_app_todolist_des")
    ],[
        localText(key:"recommended_app_nanopita"),
        localText(key:"recommended_app_nanopita_title"),
        localText(key:"recommended_app_nanopita_des")
    ],[
        localText(key:"recommended_app_mr_stick"),
        localText(key:"recommended_app_mr_stick_title"),
        localText(key:"recommended_app_mr_stick_des")
    ]
]

let settingSectionAppIntro = [("scancamera",""),("todolist",""),("nanopita",""),("mr_stick","")]
var settingSectionAD = [("","")]
let settingSection4 = [("",""),("","")]
var settingSectionData = [settingSectionSetting, settingSectionAppIntro, settingSectionAppInfo, settingSectionAD, settingSection4]
let settingSectionData_mukakin = [settingSectionSetting, settingSectionRemoveAD, settingSectionAppInfo, settingSectionAppIntro]
let settingSectionData_dev = [settingSectionSetting_dev, settingSectionRemoveAD, settingSectionAppIntro, settingSectionAppInfo]
let settingSectionData_kakin = [settingSectionSetting,settingSectionAppIntro, settingSectionAppInfo]

    
// メール系
let MAIL_TITLE_IMPROVEMENT_REQUEST : String = localText(key:"mail_title_req")
let MAIL_TITLE_INQUIRY_VIOLATION_REPORT : String = localText(key:"mail_title_faq")
let MAIL_ADDRES = "musicA.App.info@gmail.com"

// 設定値
var UPDATE_FLG = false
var FORCE_UPDATE_FLG = false
var SETTING_STARTUP_NUM : Int = 0
var SCAN_AD_INTERVAL : Int = 8
var TRAN_AD_INTERVAL : Int = 8
var RANKING_AD_INTERVAL : Int = 6
var MUSIC_LIBRARY_TO_PLAYVIEW : Int = 0
var MUSIC_LIBRARY_AD_INTERVAL : Int = 10
var SEARCH_TO_MV : Int = 0
var SEARCH_MV_AD_INTERVAL : Int = 6
var SEARCH_RECOMMEND_AD = false

// Youtube検索ジャンル
let SETTING_CATEGORYID : [Int] = [0,1,2,10,15,17,19,20,22,23,24,25,26,27,28,29,30,43,44] // 3つ目をデフォルトとして扱う
var SETTING_NOW_CATEGORYID : Int = SETTING_CATEGORYID[0]
let SETTING_CATEGORY_NAME : [String] =
    [
        localText(key:"search_janre_sougou"),
        localText(key:"search_janre_eigaanime"),
        localText(key:"search_janre_norimono"),
        localText(key:"search_janre_music"),
        localText(key:"search_janre_animal"),
        localText(key:"search_janre_sports"),
        localText(key:"search_janre_tripevent"),
        localText(key:"search_janre_game"),
        localText(key:"search_janre_blog"),
        localText(key:"search_janre_comedy"),
        localText(key:"search_janre_entertainment"),
        localText(key:"search_janre_news"),
        localText(key:"search_janre_howto"),
        localText(key:"search_janre_education"),
        localText(key:"search_janre_technology"),
        localText(key:"search_janre_society"),
        localText(key:"search_janre_anime"),
        localText(key:"search_janre_entertainment"),
        localText(key:"search_janre_movietrailer")
] // 3つ目をデフォルトとして扱う

// 表示コンテンツ数
let SETTING_DISPLAY_CONTENTS_NUM_ARRAY : [Int] = [5,10,15,20,30,40,50,99] // 3つ目をデフォルトとして扱う
var SETTING_DISPLAY_CONTENTS_NUM : Int = SETTING_DISPLAY_CONTENTS_NUM_ARRAY[3]
var SETTING_DISPLAY_RANKING_NUM : Int = SETTING_DISPLAY_CONTENTS_NUM_ARRAY[7]


// 歌詞の文字サイズ
var SETTING_LYRIC_SIZE_NUM : Int = 3 // 3つ目をデフォルトとして扱う
let SETTING_LYRIC_SIZE_NUM_ARRAY : [Int] = [10,12,14,16,20,30] // 目をデフォルトとして扱う
let SETTING_LYRIC_SIZE_NAME_ARRAY : [String] =
    [
        localText(key:"moji_size_0"),
        localText(key:"moji_size_1"),
        localText(key:"moji_size_2"),
        localText(key:"moji_size_3"),
        localText(key:"moji_size_4"),
        localText(key:"moji_size_5")
] // 目をデフォルトとして扱う

// アプリURL
var INTRODUCTION_URL: String = "itunes.apple.com/jp/app/apple-store/id1288959420"
var APP_REVIEW_URL : String = "https://itunes.apple.com/us/app/itunes-u/id1288959420?action=write-review"
var LINE_INTRODUCTION_MESSAGE: String = localText(key:"intro_message")

// アプリURL
var SCANCAMERA_INTRODUCTION_URL: String = "https://itunes.apple.com/jp/app/apple-store/id1381356031"
var TODOLIST_INTRODUCTION_URL: String = "https://itunes.apple.com/jp/app/apple-store/id1492491961"
var MR_STICK_INTRODUCTION_URL: String = "https://itunes.apple.com/jp/app/apple-store/id1443194639"
var NANOPITA_INTRODUCTION_URL: String = "https://itunes.apple.com/jp/app/apple-store/id1461700387"

var REVIEW_DONE_FLG = false
var TWITTER_DONE_FLG = false
/*----------------------------------------------------------------
 メッセージ
 ----------------------------------------------------------------*/
let MESSAGE_YES : String = localText(key:"btn_yes")
let MESSAGE_NO : String = localText(key:"btn_no")
let MESSAGE_OK : String = localText(key:"btn_ok")
let MESSAGE_CANCEL : String = localText(key:"btn_cancel")
let MESSAGE_SUCCESS : String = localText(key:"btn_success")
let MESSAGE_FAILURE : String = localText(key:"btn_failure")
let MESSAGE_CLOSE : String = localText(key:"btn_close")

// 音楽ライブラリ作成
let MESSAGE_NONE_TITLE = localText(key:"musiclibrary_err_nomusic")
let MESSAGE_NONE_MUSIC_BODY = localText(key:"musiclibrary_err_album_nomusic")
let MESSAGE_NONE_LIBRARY_BODY = localText(key:"musiclibrary_err_playlist_nomusic")

// お気に入り
let OKINIIRI_HOWTO_REGIST_LONGTAP = localText(key:"okiniiri_longtap")

// iTunes
let ITUNE_RANKING_ERR = localText(key:"err")
let ITUNE_RANKING_ERR_CANT_SHOW_CONTENTS = localText(key:"err_nocontents")
let ITUNE_RANKING_ERR_SESSION = localText(key:"network_err_msg")

// Youtube メッセージ
let MV_PLAY_FAILURE_TITLE = localText(key:"okiniiri_failure_playmv")
let MV_PLAY_FAILURE_CANT_PLAYTYPEMV = localText(key:"okiniiri_cantplaymv")
let MV_PLAY_FAILURE_CANT_PLAYTYPEMV_CANSEL = localText(key:"okiniiri_redo")
let RATE_SET_FAILURE_TITLE = localText(key:"okiniiri_failure_setspeed")
let RATE_SET_FAILURE_BODY = localText(key:"okiniiri_incompatible_speed1")
let RATE_SET_FAILURE_BODY_A = localText(key:"okiniiri_incompatible_speed2")
let RATE_SET_FAILURE_BODY_B = localText(key:"okiniiri_incompatible_speed2_setneer")
let RATE_SET_FAILURE_BODY_DONE = localText(key:"okiniiri_setspeed")
let RATE_SET_FAILURE_BODY_UNKNOWN = localText(key:"okiniiri_err_incompatible_spped")
let MV_PLAY_FAILURE_NETWORK = localText(key:"okiniiri_err_network")

//　PUSHタイトル
let PUSH_TITLE : String = localText(key:"push_title")

// アプリ誘導
let APP_INTRO_SCANCAMERA_TITLE : String = localText(key:"app_intro_title")
let APP_INTRO_SCANCAMERA_BODY : String = localText(key:"app_intro_body_scancamera")

// レビュー誘導
let REVIEW_TITLE : String = localText(key:"review_app_title")
let REVIEW_MESSAGE : String = localText(key:"review_app_body")
let REVIEW_BTN_OK : String = localText(key:"review_app_yes")
let REVIEW_BTN_NO : String = localText(key:"review_app_no")
let REVIEW_BTN_LATER : String = localText(key:"review_app_layter")

// 課金誘導
let KAKIN_TITLE : String = localText(key:"kakin_app_title")
let KAKIN_MESSAGE : String = localText(key:"kakin_app_body")
let KAKIN_BTN_OK : String = localText(key:"kakin_app_yes")
let KAKIN_BTN_STAY : String = localText(key:"kakin_app_stay")
let KAKIN_BTN_NO : String = localText(key:"kakin_app_no")


//　アップデート関連
let FORCE_UPDATE_DIALOG_TITLE : String = localText(key:"update_newver_force_title")
let FORCE_UPDATE_DIALOG_MESSAGE : String = localText(key:"update_newver_force_body")
let OPTIONAL_UPDATE_DIALOG_TITLE : String = localText(key:"update_newver_title")
let OPTIONAL_UPDATE_DIALOG_MESSAGE : String = localText(key:"update_newver_body")

//　音楽ライブラリ登録
let LISTMODE_ALBUM_MSG = localText(key:"musiclibrary_select_fromalbum")
let LISTMODE_LIVRARY_MSG = localText(key:"musiclibrary_select_library")
let LISTMODE_LIVRARY_DELETE = localText(key:"musiclibrary_delete_msg")
let LISTMODE_LIVRARY_NOSELECTED = MUSICLIBRALY_REGIST_ERR_NONSELECT_DIALOG_MESSAGE

// 音楽トラック
let LISTMODE_LIVRARY_DELETE_TRACK = localText(key:"musiclibrary_delete_track_msg")

// 音楽再生
let ERR_DIALOGUE_TITLE_MUSIC_DATA_NONE : String = localText(key:"musiclibrary_err_cantplay_title")
let ERR_DIALOGUE_MESSAGE_MUSIC_DATA_NONE : String = localText(key:"musiclibrary_err_cantplay_nodownload")
let CANT_PLAY_MUSIC = localText(key:"musiclibrary_err_cantplay")
let CANT_PLAY_MUSIC_NOW_EDIT = localText(key:"musiclibrary_err_cantplay_nowedit")
let DIALOGUE_TITLE_MUSIC_DATA_IN_CLOUD : String = localText(key:"musiclibrary_err_cantregister_title")
let DIALOGUE_MESSAGE_MUSIC_IN_CLOUD : String = localText(key:"musiclibrary_err_cantregister_body")
let DIALOGUE_TITLE_MUSIC_DATA_DRM : String = localText(key:"musiclibrary_err_cantregister_title_drm")
let DIALOGUE_MESSAGE_MUSIC_DRM : String = localText(key:"musiclibrary_err_cantregister_body_drm")

// 歌詞編集
let CONFIRM_DIALOGUE_TITLE_UPDATE_LYLIC_DATA : String = localText(key:"musiclibrary_lylic_regist_title")
let SUCCESS_DIALOGUE_MESSAGE_UPDATE_LYLIC_DATA : String = localText(key:"musiclibrary_lylic_regist_success")
let FAILURE_DIALOGUE_MESSAGE_UPDATE_LYLIC_DATA : String = localText(key:"musiclibrary_lylic_regist_failure")
let GET_COPY_LYLIC_DATA : String = localText(key:"musiclibrary_lylic_copy")
let CONFIRM_DIALOGUE_TITLE_GET_CHAR : String = localText(key:"musiclibrary_scan_text")

// TOP画面
let MUSICLIBRALY_DELETE_DIALOG_TITLE : String = localText(key:"musiclibrary_err_cant_delete")
let MUSICLIBRALY_DELETE_DIALOG_MASSAGE : String = localText(key:"musiclibrary_err_cant_delete_okiniiri")
let MUSICLIBRALY_REGIST_COMP_TOAST : String = localText(key:"musiclibrary_regist_comp_toast")

// MusicLibraly登録画面
let MUSICLIBRALY_REGIST_COMP_DIALOG_TITLE : String = localText(key:"musiclibrary_regist_comp_title")
let MUSICLIBRALY_REGIST_COMP_DIALOG_MESSAGE : String = localText(key:"musiclibrary_regist_comp_body")
let MUSICLIBRALY_REGIST_ERR_COREDATA_DIALOG_TITLE : String = localText(key:"musiclibrary_regist_err")
let MUSICLIBRALY_REGIST_ERR_COREDATA_DIALOG_MASSAGE : String = localText(key:"musiclibrary_regist_err_humei")
let MUSICLIBRALY_REGIST_ERR_NONNAME_DIALOG_TITLE : String = localText(key:"musiclibrary_regist_err_noname_title")
let MUSICLIBRALY_REGIST_ERR_NONNAME_DIALOG_MESSAGE : String = localText(key:"musiclibrary_regist_err_noname_body")
let MUSICLIBRALY_REGIST_ERR_NONSELECT_DIALOG_TITLE : String = localText(key:"musiclibrary_regist_err_noselect_title")
let MUSICLIBRALY_REGIST_ERR_NONSELECT_DIALOG_MESSAGE : String = localText(key:"musiclibrary_regist_err_noselect_body")
let MUSICLIBRALY_REGIST_ERR_SAMENAME_DIALOG_TITLE : String = localText(key:"musiclibrary_regist_err_samename_title")
let MUSICLIBRALY_REGIST_ERR_SAMENAME_DIALOG_MESSAGE : String = localText(key:"musiclibrary_regist_err_samename_body")

// Youtube再生画面
let OKINIIRI_ADD_DIALOG_TITLE : String = localText(key:"okiniiri_regist_comp_title")
let OKINIIRI_ADD_DIALOG_MASSAGE : String = localText(key:"okiniiri_regist_comp_body")
let OKINIIRI_DELETE_DIALOG_TITLE : String = localText(key:"okiniiri_delete_comp_title")
let OKINIIRI_DELETE_DIALOG_MASSAGE : String = localText(key:"okiniiri_delete_comp_body")

// テキスト画面
let TEXT_ERR_DIALOG_TITLE : String = localText(key:"musiclibrary_err_network_title")
let TEXT_ERR_DIALOG_BODY : String = localText(key:"musiclibrary_err_network_body")

/*----------------------------------------------------------------
 画面ごとのテキスト
 ----------------------------------------------------------------*/
/*
 全画面共通
 */


/*
 ホーム画面
 */
let MV_LIST_NAME = localText(key:"home_okiniiri")
let CONTENTS_TYPE_MUSIC = localText(key:"home_track_num")
let CONTENTS_TYPE_MV = localText(key:"home_mv_num")
let NAVUGATION_BTN_EDIT_END : String = localText(key:"home_edit_comp")

/*
 検索画面
 */
var SEARCH_FARST_WORD = localText(key:"search_word_blank")

/*
 Music Library 一覧画面
 */
let NOT_PLAYING_TRACK_TITLE : String = localText(key:"musiclibrary_not_play")

/*
  スキャン画面
 */
var FROM_SCAN_CAMERA : Bool = false
var RESULT_TEXT : String = ""
var LYRIC_RESULT_TEXT : String = ""
var CAMERAVIEW_RESULT_TEXT : String = ""
var CAMERAVIEW_LYRIC_RESULT_TEXT : String = ""
var TRANS_TEXT = ""
var LYRIC_TRANS_TEXT = ""

/*
  使い方画面
 */
let homepageURL : String = "https://ios-app-develop.com"
let howToUseURL : String = "https://ios-app-develop.com/houtousefast"
let ppURL : String = "https://spring-star-c7ea.kurieitajojojo.workers.dev/"
let drmURL : String = "https://www.ios-app-develop.com/drm"


/*----------------------------------------------------------------
 アプリ設定値
 ----------------------------------------------------------------*/
// 音楽再生
var playListRandomFlg = false
var sectionRepeatStatus = 0
let SECTION_REPEAT_OFF = 0
let SECTION_REPEAT_ON = 1
var sectionRepeatEditFlg = false
//###サイトがモバイルと判定するようなUser-Agentを定数として用意しておく
let iPhoneUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 10_2 like Mac OS X) AppleWebKit/602.3.12 (KHTML, like Gecko) Mobile/14C89"
var REGIST_CANCEL_FLG = false


/*----------------------------------------------------------------
 広告関連の設定値
 ----------------------------------------------------------------*/
 var adDialogLoader: AdLoader!
// AdMob広告の読み込み
// let ADMOB_APPLICATION_ID : String = "ca-app-pub-1929244717899448~8036734015"
var ADMOB_BANNER_ADUNIT_ID : String = "ca-app-pub-1929244717899448/8743805786"
let ADMOB_BANNER_ADUNIT_ID_TEST : String = "ca-app-pub-3940256099942544/6300978111"
//let ADMOB_NATIVE_ADUNIT_L_ID : String = "ca-app-pub-1929244717899448/3830946418"
//let ADMOB_NATIVE_ADUNIT_M_ID : String = "ca-app-pub-1929244717899448/3466933615"
let ADMOB_NATIVE_ADVANCE_TEST : String = "ca-app-pub-1929244717899448/9501881507"
var ADMOB_NATIVE_ADVANCE : String = "ca-app-pub-1929244717899448/9501881507"
var ADMOB_NATIVE_ADVANCE_SEARCH_CONTENTS : String = "ca-app-pub-1929244717899448/6493384254"
var ADMOB_NATIVE_ADVANCE_SEARCH_RECOMMEND : String = "ca-app-pub-1929244717899448/4600514745"
var ADMOB_NATIVE_ADVANCE_DIALOG_RECOMMEND : String = "ca-app-pub-1929244717899448/2053998913"
var ADMOB_NATIVE_ADVANCE_RANKING : String = "ca-app-pub-1929244717899448/8605849185"
var ADMOB_NATIVE_ADVANCE_RANKING_CONTENTS : String = "ca-app-pub-1929244717899448/2858698488"
var ADMOB_NATIVE_ADVANCE_SETTINGS : String = "ca-app-pub-1929244717899448/8177994848"
var ADMOB_INTERSTITIAL_SCAN_OR_TRANS_test      : String = "ca-app-pub-3940256099942544/4411468910"
var ADMOB_INTERSTITIAL_SCAN_OR_TRANS      : String = "ca-app-pub-1929244717899448/1782653178"
var ADMOB_INTERSTITIAL_MV    : String = "ca-app-pub-1929244717899448/6154400842"
var ADMOB_REWARD_TRANS      : String = "ca-app-pub-1929244717899448/1972936775"
let ADMOB_REWARD_TRANS_test : String = "ca-app-pub-3940256099942544/1712485313"
let ADMOB_TEST_DEVICES : [String] = ["f64d02e02c09177a41cb598fd181a613"]
var ADMOB_INTERSTITIAL_SEARCH : String = "ca-app-pub-1929244717899448/6355500807"
var ADMOB_REWARD_AD : String = "ca-app-pub-1929244717899448/6122562869"
let ADMOB_REWARD_AD_test : String = "ca-app-pub-3940256099942544/1712485313"
var ADMOB_INTERSTITIAL_RANKING : String = "ca-app-pub-1929244717899448/9572716386"

var ADMOB_INTERSTITIAL_CUSTUM_LIBRARY : String = "ca-app-pub-1929244717899448/8288065629"
var ADMOB_INTERSTITIAL_LIBRARY : String = "ca-app-pub-1929244717899448/6339192151"

// youtube検索結果の広告表示位置制御
var SEARCH_RESULT_AD_START = 0
var SEARCH_RESULT_AD_INTERVAL = 14
var SEARCH_RESULT_MV_AD_START = 4
var SEARCH_RESULT_MV_AD_INTERVAL = 14

// Amazon広告の読み込み
let AMAZON_AD_APPLIVATION_KEY : String = "409fcb89d73d46bd8719bad8adfbeb33"

// Admax広告の読み込み
let ADMAX_ADCODE = "51feff2aea0a18045a910b2901360dd6"

// AppVandor広告読み込み
var APPVAMDOR_AD_TEST_PUBID : String = "59d43dad47785b027efc76ef6013c9af"
var APPVAMDOR_AD_PUBID_TOP : String = "65ec2b84d2f5e0511dbab19a5e32519a"
var APPVAMDOR_AD_PUBID_SETTING : String = "b5f2541f90085abd8b3f0c9880e658b5"
var APPVAMDOR_AD_PUBID_CAMERA : String = "af4302da118a82a24417c005733561ad"
var APPVAMDOR_AD_PUBID_RANKING : String = "0d9059d35cb02b2024111b7a24466299"
var APPVAMDOR_AD_PUBID_SEARCH : String = "357ccd9058042633edbedc708ffddf9d"
var APPVAMDOR_AD_PUBID : String = APPVAMDOR_AD_TEST_PUBID // TODO

// 広告表示制御
var AD_DISPLAY_SEARCH_BANNER : Bool = true
var AD_DISPLAY_SEARCH_CONTENTS : Bool = false
var AD_DISPLAY_RANKING_BANNER : Bool = true
var AD_DISPLAY_RANKING_CONTENTS : Bool = true
var AD_DISPLAY_MUSIC_LYRIC_EDIT_BANNER : Bool = true
var AD_DISPLAY_MUSICLIBRARYLIST_BANNER : Bool = true
var AD_DISPLAY_MUSIC_REGISTER_ALBUM_BANNER : Bool = true
var AD_DISPLAY_MUSIC_REGISTER_TRACK_BANNER : Bool = true
var AD_DISPLAY_SETTING_CONTENTS : Bool = true
var AD_DISPLAY_FIVE_TEST_MODE : Bool = DEBUG_FLG
var AD_DISPLAY_YOUTUBE_CONTENTS : Bool = true
var AD_DISPLAY_YOUTUBE_CONTENTS_NUM : Int = 5
var TRANS_REWARD_COUNT = 5
var MV_INTER_AD_TIME = 1000

// FIVE
var FIVE_INIT_FLG = false
var FIVE_INFEED_INIT_FLG = false

// maio
var MAIO_TAP_FLG = false
let MAIO_APP_ID = "mc315633e0f909381322f8ce36fc4d341"
let MAIO_ZONEID_INTERSTISHAL = "z5943d94111d21396005701de387d677d"
let MAIO_ZONEID_REWARD = "z05fe34c78159951851707efee80016ec"

/*----------------------------------------------------------------
 youtube認証
 ----------------------------------------------------------------*/
var API_KEY_CHANGE_FLG = false
var API_KEY : String = "AIzaSyDaJJbHaRfNcnY1T3hZDfIY2wgXBL8w2HY"
var API_KEY_YOBI : String = "AIzaSyDHYyjvdtXSKLMWXugFmBDNDJq5VYDHs4Q"
//var API_KEY_RANKING : String = "AIzaSyC035hKZInIq32cvuc36qzrEUEMI5F823Q"
//var API_KEY_SEARCH : String = "AIzaSyBk0jIRdAgT7pbaXfmlzp7pfPsnmqkQwjQ"
//let API_KEY_RANKING_nomal : String = "AIzaSyC035hKZInIq32cvuc36qzrEUEMI5F823Q"  // Raking機能で使用しているもの musica-release01
//let API_KEY_SEARCH_nomal : String = "AIzaSyBk0jIRdAgT7pbaXfmlzp7pfPsnmqkQwjQ"   // 検索機能で使用しているもの musica-release04
//var API_KEY_TOP : String = "AIzaSyDbl7G2zRw5g4R_8LNeWwUE4QmZjCLoLL8"    // メインでおすすめMV取得で使用しているもの  musica-release-tpo01
//var API_KEY_YOBI_1 : String = "AIzaSyDHYyjvdtXSKLMWXugFmBDNDJq5VYDHs4Q" // メインがあふれた場合の予備① musica-release02
//var API_KEY_YOBI_2 : String = "AIzaSyDGWq99k2BOuinrF4615quL6Hat93fOIRo" // メインがあふれた場合の予備① musica-release03
//var API_KEY_YOTUBEVIEW : String = "AIzaSyC7Y4V446IZ-w_CoIYYF0TzM7ipC5HxOww" // API_KEY_YOTUBEVIEW musica-release05
//
//let API_KEY_TEST : String = "AIzaSyACPgzq0DvGLFB024etYrODUgs2JysliEc"   // 開発者のみが使用

/*----------------------------------------------------------------
 Google VisionAPI認証
 ----------------------------------------------------------------*/
let GOOGLE_VISION_API = "AIzaSyCN1kFN4WCYV5fHGKCH_YGjVbpS2gVFuno"
//let Tesseract = 0
//let Google_vison_API = 1
//var SCANMODE = Google_vison_API
var previewImageScanCaptured : UIImage! = nil
var previewImageLyricCaptured : UIImage! = nil

/*----------------------------------------------------------------
 Firebase analytics関連
 ----------------------------------------------------------------*/
var MV_PLAY_NUM = 0
var SCAN_USE_NUM = 0
var TRANS_USE_NUM = 0
var RANKING_LOOK_NUM = 0

/*----------------------------------------------------------------
 翻訳言語関連
 ----------------------------------------------------------------*/
var BEFORE_TRANS = 0
var AFTER_TRANS = 1
var TRANS_LANG_SETTING = selectedLangList[0]
var langArray = [
    localText(key:"trans_lang_jp"),
    localText(key:"trans_lang_en"),
    localText(key:"trans_lang_ch")
]

//var RESULT_TEXT = ""
var NOW_IMAGE : UIImage? = nil
var MAX_TEXT_NUM = 2000
var GET_LANG_FLG = false
//*****used after parsing to create an array of structs with language information
struct AllLangDetails: Codable {
    var code = String()
    var name = String()
    var nativeName = String()
    var dir = String()
}
//*****Format JSON for body of translation request
struct TranslatedStrings: Codable {
    var text: String
    var to: String
}
var arrayLangInfo = [AllLangDetails]() //array of structs for language info
var selectedLangList : [AllLangDetails] = [AllLangDetails(code:"en",name:localText(key:"trans_lang_en"),nativeName:"English",dir:"ltr"),
                                           AllLangDetails(code:"ja",name:localText(key:"trans_lang_jp"),nativeName:localText(key:"trans_lang_jp"),dir:"ltr"),
                                           AllLangDetails(code:"zh-Hant",name:"繁体字中国語",nativeName:"繁體中文",dir:"ltr")
]
/*----------------------------------------------------------------
 iTunes関連
 ----------------------------------------------------------------*/
let MOST_PLAYED_MUSIC = 0
let MOST_PLAYED_VIDEO = 1

var SETTING_CONTRY_CODE = localText(key:"ranking_default_settings")
let CONTRY_CODE_JP = "jp" // 日本
let CONTRY_CODE_US = "us" // アメリカ
let CONTRY_CODE_TR = "tr" // トルコ
let CONTRY_CODE_GB = "gb" // イギリス
let CONTRY_CODE_KR = "kr" // 韓国
let CONTRY_CODE_CN = "cn" // 中国
let CONTRY_CODE_TH = "th" // タイ
let CONTRY_CODE_ES = "es" // スペイン

/*----------------------------------------------------------------
 レスポンスコード
 ----------------------------------------------------------------*/
let CODE_SUCCESS : String = "0"




