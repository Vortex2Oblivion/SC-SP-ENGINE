package states.editors;

import tjson.TJSON as Json;

import haxe.format.JsonParser;
import haxe.io.Bytes;

import flixel.FlxObject;
import flixel.FlxSubState;

import flixel.addons.display.FlxGridOverlay;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUISlider;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUIButton;
import flixel.ui.FlxButton;
import flixel.util.FlxStringUtil;
import flixel.util.FlxSort;

import lime.media.AudioBuffer;

import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.media.Sound;
import openfl.geom.Rectangle;
import openfl.net.FileReference;
import openfl.utils.Assets as OpenFlAssets;

import backend.Song;
import backend.Section;
import backend.StageData;

import objects.Note;
import objects.StrumArrow;
import objects.HealthIcon;
import objects.AttachedSprite;
import objects.Character;

import substates.Prompt;

@:access(flixel.sound.FlxSound._sound)
@:access(openfl.media.Sound.__buffer)

class ChartingState extends MusicBeatState
{
	private var songStarted:Bool = false;
	public static var noteTypeList:Array<String> = //Used for backwards compatibility with 0.1 - 0.3.2 charts, though, you should add your hardcoded custom note types here too.
	[
		'',
		'Alt Animation',
		'Hey!',
		'Hurt Note',
		'GF Sing',
		'Mom Sing',
		'No Animation'
	];
	public var ignoreWarnings = false;
	var curNoteTypes:Array<String> = [];
	var undos = [];
	var redos = [];
	var eventStuff:Array<Dynamic> =
	[
		['', "Nothing. Yep, that's right."],
		['Dadbattle Spotlight', "Used in Dad Battle,\nValue 1: 0/1 = ON/OFF,\n2 = Target Dad\n3 = Target BF"],
		['Hey!', "Plays the \"Hey!\" animation from Bopeebo,\nValue 1: BF = Only Boyfriend, GF = Only Girlfriend,\nSomething else = Both.\nValue 2: Custom animation duration,\nleave it blank for 0.6s"],
		['Set GF Speed', "Sets GF head bopping speed,\nValue 1: 1 = Normal speed,\n2 = 1/2 speed, 4 = 1/4 speed etc.\nUsed on Fresh during the beatbox parts.\n\nWarning: Value must be integer!"],
		['Philly Glow', "Exclusive to Week 3\nValue 1: 0/1/2 = OFF/ON/Reset Gradient\n \nNo, i won't add it to other weeks."],
		['Kill Henchmen', "For Mom's songs, don't use this please, i love them :("],
		['Add Camera Zoom', "Used on MILF on that one \"hard\" part\nValue 1: Camera zoom add (Default: 0.015)\nValue 2: UI zoom add (Default: 0.03)\nLeave the values blank if you want to use Default."],
		['BG Freaks Expression', "Should be used only in \"school\" Stage!"],
		['Trigger BG Ghouls', "Should be used only in \"schoolEvil\" Stage!"],
		['Main Camera Flash', "Create a flash effect in a camera.\n\"Value 1: Color (in Hexidecimal)\n(ex: 000000 FFFFFF 30A0F0)\n\nValue 2: Duration (in Seconds).\n\nValue 3: Choosen Camera. \n\nValue 4: Alpha Float of the color to flash."],
		['Set Main Cam Zoom', "Change the zoom camera \"Value 1: the zoom value\nValue 2: if blank, it will smoothly zoom regularly,\notherwise it will do an instant zoom"],
		['Play Animation', "Plays an animation on a Character,\nonce the animation is completed,\nthe animation changes to Idle\n\nValue 1: Animation to play.\nValue 2: Character (Dad, BF, GF)"],
		['Camera Follow Pos', "Value 1: X\nValue 2: Y\n\nThe camera won't change the follow point\nafter using this, for getting it back\nto normal, leave both values blank\nValue 3: camZoom\nLeave blank for original zoom,\notherwise,\nchanges the camera zoom."],
		['Alt Idle Animation', "Sets a specified suffix after the idle animation name.\nYou can use this to trigger 'idle-alt' if you set\nValue 2 to -alt\n\nValue 1: Character to set (Dad, BF or GF)\nValue 2: New suffix (Leave it blank to disable)"],
		['Screen Shake', "Value 1: Camera shake\nValue 2: HUD shake\n\nEvery value works as the following example: \"1, 0.05\".\nThe first number (1) is the duration.\nThe second number (0.05) is the intensity."],
		['Change Character', "Value 1: Character to change (Dad, BF, GF)\nValue 2: New character's name"],
		['Change Stage', "Changes the Stage\nValue 1: Stage's Name\nValue 2:Free value for use with onEvent"],
		['Change Scroll Speed', "Value 1: Scroll Speed Multiplier (1 is default)\nValue 2: Time it takes to change fully in seconds."],
		['Set Property', "Value 1: Variable name\nValue 2: New value"],
		['Play Sound', "Value 1: Sound file name\nValue 2: Volume (Default: 1), ranges from 0 to 1"],
		['Reset Animation', "Resets the characters animation vars\n\nValue 1: Character Name\nValue 2: Nothing"],
		['AddCinematicBars', "value 1 refers to which speed they appear. \nValue 2 refers to the thickness of the bars"],
		['RemoveCinematicBars', "value 1 refers to which speed they disappear. \nValue 2 refers to nothing"],
		['New Camera Target', "value 2 refers to where it's forced or not\n('true' or 'false') \n value 1 refers to which char is the camera forced on\n('dad', 'gf', 'bf')"]
	];

	var _file:FileReference;

	var UI_box:FlxUITabMenu;

	public static var goToPlayState:Bool = false;
	/**
	 * Array of notes showing when each section STARTS in STEPS
	 * Usually rounded up??
	 */
	public static var curSec:Int = 0;
	public static var lastSection:Int = 0;
	private static var lastSong:String = '';

	var bpmTxt:FlxText;

	var camPos:FlxObject;
	var strumLine:FlxSprite;
	var quant:AttachedSprite;
	var strumLineNotes:FlxTypedGroup<StrumArrow>;
	var curSong:String = 'Test';
	var amountSteps:Int = 0;
	var bullshitUI:FlxGroup;

	var highlight:FlxSprite;

	public static var GRID_SIZE:Int = 40;
	var CAM_OFFSET:Int = 360;

	var dummyArrow:FlxSprite;

	var curRenderedSustains:FlxTypedGroup<FlxSprite>;
	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedNoteType:FlxTypedGroup<FlxText>;

	var nextRenderedSustains:FlxTypedGroup<FlxSprite>;
	var nextRenderedNotes:FlxTypedGroup<Note>;

	var gridBG:FlxSprite;
	var nextGridBG:FlxSprite;

	var daquantspot = 0;
	var curEventSelected:Int = 0;
	var curUndoIndex = 0;
	var curRedoIndex = 0;
	var _song:SwagSong;
	/*
	 * WILL BE THE CURRENT / LAST PLACED NOTE
	**/
	var curSelectedNote:Array<Dynamic> = null;

	var playbackSpeed:Float = 1;

	var vocals:FlxSound = null;
	var opponentVocals:FlxSound = null;

	var leftIcon:HealthIcon;
	var rightIcon:HealthIcon;

	var value1InputText:FlxUIInputText;
	var value2InputText:FlxUIInputText;
	var value3InputText:FlxUIInputText;
	var value4InputText:FlxUIInputText;
	var value5InputText:FlxUIInputText;
	var value6InputText:FlxUIInputText;
	var value7InputText:FlxUIInputText;
	var value8InputText:FlxUIInputText;
	var value9InputText:FlxUIInputText;
	var value10InputText:FlxUIInputText;
	var value11InputText:FlxUIInputText;
	var value12InputText:FlxUIInputText;
	var value13InputText:FlxUIInputText;
	var value14InputText:FlxUIInputText;

	var zoomFactorTxt:String = "1 / 1";

	var zoomList:Array<Float> = [
		0.25,
		0.5,
		1,
		2,
		3,
		4,
		6,
		8,
		12,
		16,
		24
	];
	var curZoom:Int = 2;

	var currentSongName:String;

	private var blockPressWhileTypingOn:Array<FlxUIInputText> = [];
	private var blockPressWhileTypingOnStepper:Array<FlxUINumericStepper> = [];
	private var blockPressWhileScrolling:Array<FlxUIDropDownMenu> = [];

	var waveformSprite:FlxSprite;
	var gridLayer:FlxTypedGroup<FlxSprite>;

	public static var quantization:Int = 16;
	public static var curQuant = 3;

	public var quantizations:Array<Int> = [
		4,
		8,
		12,
		16,
		20,
		24,
		32,
		48,
		64,
		96,
		192
	];

	var text:String = "";
	public static var vortex:Bool = false;
	public var mouseQuant:Bool = false;

	public var player1:Character;
	public var player2:Character;

	public static var mustCleanMem:Bool = false;

	var camHUD:FlxCamera;
	var camGame:FlxCamera;

	var hasUnsavedChanges = false; //Copies modcharteditor's way of telling if something changed!

	var helpBg:FlxSprite;
	var helpTexts:FlxSpriteGroup;
	override function create()
	{	
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		
		if (PlayState.SONG != null)
			_song = PlayState.SONG;
		else
		{
			Difficulty.resetList();
			_song = {
				songId: 'Test',
				song: 'Test',
				notes: [],
				events: [],
				bpm: 150.0,
				needsVoices: true,
				player1: 'bf',
				player2: 'dad',
				player4: 'mom',
				gfVersion: 'gf',
				speed: 1,
				stage: 'stage',
				notITG: false,
				usesHUD: false,
				noIntroSkip: false,
				rightScroll: false,
				middleScroll: false
			};
			addSection();
			PlayState.SONG = _song;
		}

		camGame = initPsychCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		FlxG.cameras.add(camHUD, false);

		player2 = new Character(0, 0, _song.player2);
		player1 = new Character(0, 0, _song.player1);

		IndieDiamondTransSubState.divideZoom = false;
		IndieDiamondTransSubState.placedZoom = 1.2;

		// Paths.clearMemory();

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Chart Editor", _song.songId);
		#end

		vortex = FlxG.save.data.chart_vortex;
		ignoreWarnings = FlxG.save.data.ignoreWarnings;
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set();
		bg.color = 0xFF222222;
		bg.scale.set(1.2, 1.2);
		add(bg);

		gridLayer = new FlxTypedGroup<FlxSprite>();
		add(gridLayer);

		waveformSprite = new FlxSprite(GRID_SIZE, 0).makeGraphic(1, 1, 0x00FFFFFF);
		add(waveformSprite);

		var eventIcon:FlxSprite = new FlxSprite(-GRID_SIZE - 5, -90).loadGraphic(Paths.image('eventArrow'));
		eventIcon.antialiasing = ClientPrefs.data.antialiasing;

		leftIcon = new HealthIcon(_song.player1, false, true, true);
		rightIcon = new HealthIcon(_song.player2, false, true, true);
		eventIcon.scrollFactor.set(1, 1);
		leftIcon.scrollFactor.set(1, 1);
		rightIcon.scrollFactor.set(1, 1);

		eventIcon.setGraphicSize(30, 30);
		if (!leftIcon.animatedIcon) leftIcon.setGraphicSize(0, 45);
		if (!rightIcon.animatedIcon) rightIcon.setGraphicSize(0, 45);
		if (leftIcon.animatedIcon) leftIcon.scale.set(0.5, 0.5);
		if (rightIcon.animatedIcon) rightIcon.scale.set(0.5, 0.5);

		add(eventIcon);
		add(leftIcon);
		add(rightIcon);

		leftIcon.setPosition(GRID_SIZE + 10, -100);
		rightIcon.setPosition(GRID_SIZE * 5.2, -100);

		curRenderedSustains = new FlxTypedGroup<FlxSprite>();
		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedNoteType = new FlxTypedGroup<FlxText>();

		nextRenderedSustains = new FlxTypedGroup<FlxSprite>();
		nextRenderedNotes = new FlxTypedGroup<Note>();

		FlxG.mouse.visible = true;
		//FlxG.save.bind('funkin', CoolUtil.getSavePath());

		//addSection();

		// sections = _song.notes;

		updateJsonData();
		currentSongName = Paths.formatToSongPath(_song.song);
		loadSong();
		reloadGridLayer();
		Conductor.bpm = _song.bpm;
		Conductor.mapBPMChanges(_song);
		if(curSec >= _song.notes.length) curSec = _song.notes.length - 1;

		bpmTxt = new FlxText(10, 50, 0, "", 16);
		bpmTxt.scrollFactor.set();
		add(bpmTxt);

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(GRID_SIZE * 9), 4);
		add(strumLine);

		quant = new AttachedSprite('chart_quant','chart_quant');
		quant.animation.addByPrefix('q','chart_quant',0,false);
		quant.animation.play('q', true, false, 0);
		quant.sprTracker = strumLine;
		quant.xAdd = -32;
		quant.yAdd = 8;
		add(quant);

		if (_song.arrowSkin == null && PlayState.isPixelStage)
		{
			_song.arrowSkin = 'pixel';
		}

		strumLineNotes = new FlxTypedGroup<StrumArrow>();
		for (i in 0...8){
			var note:StrumArrow = new StrumArrow(GRID_SIZE * (i+1), strumLine.y, i % 4, 0, _song.arrowSkin);
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.updateHitbox();
			note.playAnim('static', true);
			strumLineNotes.add(note);
			note.scrollFactor.set(1, 1);
		}
		add(strumLineNotes);

		camPos = new FlxObject(0, 0, 1, 1);
		camPos.setPosition(strumLine.x + CAM_OFFSET, strumLine.y);

		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);
		dummyArrow.antialiasing = ClientPrefs.data.antialiasing;
		add(dummyArrow);

		var tabs = [
			{name: "Song", label: 'Song'},
			{name: "Section", label: 'Section'},
			{name: "Note", label: 'Note'},
			{name: "Charting", label: 'Charting'},
		];

		var tabs2 = [
			{name: "Events", label: 'Events'},
			{name: "Data", label: 'Data'},
		];

		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box2 = new FlxUITabMenu(null, tabs2, true);

		UI_box.resize(300, 400);
		UI_box.x = -90 + GRID_SIZE / 2;
		UI_box.y = 365;
		UI_box.scrollFactor.set();

		UI_box2.resize(655, 670);
		UI_box2.x = 640 + GRID_SIZE / 2;
		UI_box2.y = 25;
		UI_box2.scrollFactor.set();

		add(UI_box);
		add(UI_box2);

		var startHere:FlxButton = new FlxButton(UI_box2.x, UI_box2.y - 30, 'Start Here', function()
		{
			PlayState.timeToStart = Conductor.songPosition;
			startSong();
		});
		add(startHere);

		addSongUI();
		addSectionUI();
		addNoteUI();
		addChartingUI();
		addDataUI();
		updateHeads();
		updateWaveform();

		addEventsUI();
		//UI_box.selected_tab = 4;

		add(curRenderedSustains);
		add(curRenderedNotes);
		add(curRenderedNoteType);
		add(nextRenderedSustains);
		add(nextRenderedNotes);

		if(lastSong != currentSongName) {
			changeSection();
		}
		lastSong = currentSongName;

		updateGrid();

		var tipText:FlxText = new FlxText(FlxG.width - 300, FlxG.height - 24, 300, "Press F1 for Help", 16);
		tipText.cameras = [camHUD];
		tipText.setFormat(null, 16, FlxColor.WHITE, RIGHT, OUTLINE_FAST, FlxColor.BLACK);
		tipText.borderColor = FlxColor.BLACK;
		tipText.scrollFactor.set();
		tipText.borderSize = 1;
		tipText.active = false;
		add(tipText);

		addHelpScreen();

		super.create();
	}

	function addHelpScreen()
	{
		var str:String = "CHARTING
		\nW/S or Mouse Wheel - Change Conductor's strum time
		\nH - Go to the start of the chart
		\nA/D - Go to the previous/next section
		\nUp/Down - Change Conductor's Strum Time with Snapping
		\nHold Shift - Move 4x faster Conductor's strum time

		\nSNAP
		\nLeft/Right - Change Snap
		\nHold Control + click on an arrow - Select it
		\nHold Control + Left/Right - Move selected arrow

		\nEXTRA
		\nZ/X - Zoom in/out
		\nEsc - Test your chart inside Chart Editor
		\nEnter - Play your chart
		\nQ/E - Decrease/Increase Note Sustain Length
		\nSpace - Stop/Resume song";

		#if FLX_PITCH
		str += "

		\nPITCH
		\nLeft Bracket / Right Bracket - Change Song Playback Rate (SHIFT to go Faster)
		
		\nALT + Left Bracket / Right Bracket - Reset Song Playback Rate";
		#end

		helpBg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		helpBg.scale.set(FlxG.width, FlxG.height);
		helpBg.updateHitbox();
		helpBg.alpha = 0.4;
		helpBg.cameras = [camHUD];
		helpBg.active = helpBg.visible = false;
		add(helpBg);

		var arr = str.split('\n');
		helpTexts = new FlxSpriteGroup();
		helpTexts.cameras = [camHUD];
		for (i in 0...arr.length)
		{
			if(arr[i].length < 2) continue;

			var helpText:FlxText = new FlxText(0, 0, 600, arr[i], 16);
			helpText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
			helpText.borderColor = FlxColor.BLACK;
			helpText.scrollFactor.set();
			helpText.borderSize = 1;
			helpText.screenCenter();
			add(helpText);
			helpText.y += ((i - arr.length/2) * 16);
			helpText.active = false;
			helpTexts.add(helpText);
		}
		helpTexts.active = helpTexts.visible = false;
		add(helpTexts);
	}

	var UI_box2:FlxUITabMenu;

	var check_mute_inst:FlxUICheckBox = null;
	var check_mute_vocals:FlxUICheckBox = null;
	var check_mute_vocals_opponent:FlxUICheckBox = null;
	var check_vortex:FlxUICheckBox = null;
	var check_warnings:FlxUICheckBox = null;
	var playSoundBf:FlxUICheckBox = null;
	var playSoundDad:FlxUICheckBox = null;
	var UI_songTitle:FlxUIInputText;
	var stageDropDown:FlxUIDropDownMenu;
	#if FLX_PITCH
	var sliderRate:FlxUISlider;
	#end
	var notITGModchart:FlxUICheckBox = null;
	var difficultyDropDown:FlxUIDropDownMenu;
	var usingHUD:FlxUICheckBox = null;
	function addSongUI():Void
	{
		UI_songTitle = new FlxUIInputText(10, 10, 70, _song.songId, 8);
		blockPressWhileTypingOn.push(UI_songTitle);

		var check_voices = new FlxUICheckBox(10, 25, null, null, "Has voice track", 100);
		check_voices.checked = _song.needsVoices;
		// _song.needsVoices = check_voices.checked;
		check_voices.callback = function()
		{
			_song.needsVoices = check_voices.checked;
			//Debug.logTrace('CHECKED!');
		};

		var saveButton:FlxButton = new FlxButton(110, 8, "Save", function()
		{
			saveLevel();
			hasUnsavedChanges = false;
		});

		var reloadSong:FlxButton = new FlxButton(saveButton.x + 90, saveButton.y, "Reload Audio", function()
		{
			currentSongName = Paths.formatToSongPath(UI_songTitle.text);
			updateJsonData();
			loadSong();
			updateWaveform();
		});

		var reloadSongJson:FlxButton = new FlxButton(reloadSong.x, saveButton.y + 30, "Reload JSON", function()
		{
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, function() {
				updateJsonData();
				loadJson(_song.songId.toLowerCase());
			},
			null, ignoreWarnings));
		});

		var loadAutosaveBtn:FlxButton = new FlxButton(reloadSongJson.x, reloadSongJson.y + 30, 'Load Autosave', function()
		{
			PlayState.SONG = Song.parseJSONshit(FlxG.save.data.autosave);
			if(PlayState.SONG.song != null && PlayState.SONG.songId == null) PlayState.SONG.songId = PlayState.SONG.song;
			else if(PlayState.SONG.songId != null && PlayState.SONG.song == null) PlayState.SONG.song = PlayState.SONG.songId;
			reloadState();
		});

		var loadEventJson:FlxButton = new FlxButton(loadAutosaveBtn.x, loadAutosaveBtn.y + 30, 'Load Events', function()
		{

			var songName:String = Paths.formatToSongPath(_song.songId);
			var file:String = Paths.json('songs/' + songName + '/events');
			#if sys
			if (#if MODS_ALLOWED FileSystem.exists(Paths.modsJson('songs/' + songName + '/events')) || #end FileSystem.exists(file))
			#else
			if (OpenFlAssets.exists(file))
			#end
			{
				clearEvents();
				var events:SwagSong = Song.loadFromJson('events', songName);
				_song.events = events.events;
				changeSection(curSec);
			}
		});

		var saveEvents:FlxButton = new FlxButton(110, reloadSongJson.y, 'Save Events', function ()
		{
			saveEvents();
		});

		var clear_events:FlxButton = new FlxButton(200, 310, 'Clear events', function()
			{
				openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, clearEvents, null,ignoreWarnings));
				hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			});
		clear_events.color = FlxColor.RED;
		clear_events.label.color = FlxColor.WHITE;

		var clear_notes:FlxButton = new FlxButton(200, clear_events.y + 30, 'Clear notes', function() {
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, function(){for (sec in 0..._song.notes.length) {
				_song.notes[sec].sectionNotes = [];
			}
				updateGrid();
			}, null,ignoreWarnings));
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			updateGrid();
		});
		clear_notes.color = FlxColor.RED;
		clear_notes.label.color = FlxColor.WHITE;

		var stepperBPM:FlxUINumericStepper = new FlxUINumericStepper(10, 70, 1, 1, 1, 400, 3);
		stepperBPM.value = Conductor.bpm;
		stepperBPM.name = 'song_bpm';
		blockPressWhileTypingOnStepper.push(stepperBPM);

		var stepperSpeed:FlxUINumericStepper = new FlxUINumericStepper(10, stepperBPM.y + 35, 0.1, 1, 0.1, 10, 2);
		stepperSpeed.value = _song.speed;
		stepperSpeed.name = 'song_speed';
		blockPressWhileTypingOnStepper.push(stepperSpeed);

		var tab_group_song = new FlxUI(null, UI_box);
		tab_group_song.name = "Song";
		tab_group_song.add(UI_songTitle);

		var swagSongGroup:Array<Dynamic> = [
			check_voices, clear_events, clear_notes, saveButton, saveEvents, reloadSong, reloadSongJson, loadAutosaveBtn,
			loadEventJson, stepperBPM, stepperSpeed
		];

		for (i in 0...swagSongGroup.length)
		{
			tab_group_song.add(swagSongGroup[i]);
		}

		tab_group_song.add(new FlxText(stepperBPM.x, stepperBPM.y - 15, 0, 'Song BPM:'));
		//tab_group_song.add(new FlxText(stepperBPM.x + 100, stepperBPM.y - 15, 0, 'Song Offset:'));
		tab_group_song.add(new FlxText(stepperSpeed.x, stepperSpeed.y - 15, 0, 'Song Speed:'));

		UI_box.addGroup(tab_group_song);

		camGame.follow(camPos, LOCKON, 999);
		camGame.zoom = 0.9;
	}

	var stepperBeats:FlxUINumericStepper;
	var check_mustHitSection:FlxUICheckBox;
	var check_gfSection:FlxUICheckBox;
	var check_changeBPM:FlxUICheckBox;
	var stepperSectionBPM:FlxUINumericStepper;
	var check_altAnim:FlxUICheckBox;
	var check_CPUAltAnim:FlxUICheckBox;
	var check_playerAltAnim:FlxUICheckBox;
	var stepperDType:FlxUINumericStepper;
	var check_player4Section:FlxUICheckBox;

	var sectionToCopy:Int = 0;
	var notesCopied:Array<Dynamic>;

	var stepperSection:FlxUINumericStepper;

	function addSectionUI():Void
	{
		var tab_group_section = new FlxUI(null, UI_box);
		tab_group_section.name = 'Section';

		check_mustHitSection = new FlxUICheckBox(10, 15, null, null, "Must hit section", 100);
		check_mustHitSection.name = 'check_mustHit';
		check_mustHitSection.checked = _song.notes[curSec].mustHitSection;

		check_gfSection = new FlxUICheckBox(10, check_mustHitSection.y + 22, null, null, "GF section", 100);
		check_gfSection.name = 'check_gf';
		check_gfSection.checked = _song.notes[curSec].gfSection;
		// _song.needsVoices = check_mustHit.checked;

		check_altAnim = new FlxUICheckBox(check_gfSection.x + 110, check_gfSection.y + 22, null, null, "Alt Animation", 100);
		check_altAnim.checked = _song.notes[curSec].altAnim;
		check_altAnim.name = 'check_altAnim';

		check_player4Section = new FlxUICheckBox(check_gfSection.x, check_gfSection.y + 22, null, null, "Player 4 Section", 100);
		check_player4Section.name = 'check_player4section';
		check_player4Section.checked = _song.notes[curSec].player4Section;

		stepperBeats = new FlxUINumericStepper(10, 100, 1, 4, 1, 7, 2);
		stepperBeats.value = getSectionBeats();
		stepperBeats.name = 'section_beats';
		blockPressWhileTypingOnStepper.push(stepperBeats);
		
		check_changeBPM = new FlxUICheckBox(10, stepperBeats.y + 30, null, null, 'Change BPM', 100);
		check_changeBPM.checked = _song.notes[curSec].changeBPM;
		check_changeBPM.name = 'check_changeBPM';

		stepperSectionBPM = new FlxUINumericStepper(10, check_changeBPM.y + 20, 1, Conductor.bpm, 0, 999, 1);
		if(check_changeBPM.checked) {
			stepperSectionBPM.value = _song.notes[curSec].bpm;
		} else {
			stepperSectionBPM.value = Conductor.bpm;
		}
		stepperSectionBPM.name = 'section_bpm';
		blockPressWhileTypingOnStepper.push(stepperSectionBPM);

		stepperSection = new FlxUINumericStepper(stepperSectionBPM.x + 180, stepperSectionBPM.y + 120, 1, 0, 0, 999, 0);
		stepperSection.name = 'section_change';
		blockPressWhileTypingOnStepper.push(stepperSection);

		var jumpSectionButton:FlxButton = new FlxButton(stepperSection.x, stepperSection.y + 20, "Jump Section", function()
		{
			if (_song.notes[curSec + 1] == null || _song.notes.length < curSec)
				changeSection(0);
			else
				changeSection(Std.int(stepperSection.value));
		});

		check_CPUAltAnim = new FlxUICheckBox(check_mustHitSection.x + 110, check_mustHitSection.x, null, null, "CPU Alternate Animation", 100);
		check_CPUAltAnim.checked = _song.notes[curSec].CPUAltAnim;
		check_CPUAltAnim.name = 'check_CPUAltAnim';

		check_playerAltAnim = new FlxUICheckBox(check_gfSection.x + 110, check_gfSection.y, null, null, "Player Alternate Animation", 100);
		check_playerAltAnim.checked = _song.notes[curSec].playerAltAnim;
		check_playerAltAnim.name = 'check_playerAltAnim';

		stepperDType = new FlxUINumericStepper(130, stepperSectionBPM.y, 1, 0, 0, 999, 0);
		stepperDType.value = 0;
		stepperDType.name = 'section_dtype';

		var check_eventsSec:FlxUICheckBox = null;
		var check_notesSec:FlxUICheckBox = null;
		var copyButton:FlxButton = new FlxButton(10, 190, "Copy Section", function()
		{
			notesCopied = [];
			sectionToCopy = curSec;
			for (i in 0..._song.notes[curSec].sectionNotes.length)
			{
				var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
				notesCopied.push(note);
			}

			var startThing:Float = sectionStartTime();
			var endThing:Float = sectionStartTime(1);
			for (event in _song.events)
			{
				var strumTime:Float = event[0];
				if(endThing > event[0] && event[0] >= startThing)
				{
					var copiedEventArray:Array<Dynamic> = [];
					for (i in 0...event[1].length)
					{
						var eventToPush:Array<Dynamic> = event[1][i];
						copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2], eventToPush[3], eventToPush[4], eventToPush[5], eventToPush[6], eventToPush[7], eventToPush[8], eventToPush[9],
							eventToPush[10], eventToPush[11], eventToPush[12], eventToPush[13], eventToPush[14]
						]);
					}
					notesCopied.push([strumTime, -1, copiedEventArray]);
				}
			}
		});

		var pasteButton:FlxButton = new FlxButton(copyButton.x + 100, copyButton.y, "Paste Section", function()
		{
			if(notesCopied == null || notesCopied.length < 1)
			{
				return;
			}

			var addToTime:Float = Conductor.stepCrochet * (getSectionBeats() * 4 * (curSec - sectionToCopy));
			//Debug.logTrace('Time to add: ' + addToTime);

			for (note in notesCopied)
			{
				var copiedNote:Array<Dynamic> = [];
				var newStrumTime:Float = note[0] + addToTime;
				if(note[1] < 0)
				{
					if(check_eventsSec.checked)
					{
						var copiedEventArray:Array<Dynamic> = [];
						for (i in 0...note[2].length)
						{
							var eventToPush:Array<Dynamic> = note[2][i];
							copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2], eventToPush[3], eventToPush[4], eventToPush[5], eventToPush[6], eventToPush[7], eventToPush[8], eventToPush[9],
								eventToPush[10], eventToPush[11], eventToPush[12], eventToPush[13], eventToPush[14]
							]);
						}
						_song.events.push([newStrumTime, copiedEventArray]);
					}
				}
				else
				{
					if(check_notesSec.checked)
					{
						if(note[4] != null)
							copiedNote = [newStrumTime, note[1], note[2], note[3], note[4]];
						else
							copiedNote = [newStrumTime, note[1], note[2], note[3]];

						_song.notes[curSec].sectionNotes.push(copiedNote);
					}
				}
			}
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			updateGrid();
		});

		var clearSectionButton:FlxButton = new FlxButton(pasteButton.x + 100, pasteButton.y, "Clear", function()
		{
			if(check_notesSec.checked)
			{
				_song.notes[curSec].sectionNotes = [];
			}

			if(check_eventsSec.checked)
			{
				var i:Int = _song.events.length - 1;
				var startThing:Float = sectionStartTime();
				var endThing:Float = sectionStartTime(1);
				while(i > -1) {
					var event:Array<Dynamic> = _song.events[i];
					if(event != null && endThing > event[0] && event[0] >= startThing)
					{
						_song.events.remove(event);
					}
					--i;
				}
			}
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			updateGrid();
			updateNoteUI();
		});
		clearSectionButton.color = FlxColor.RED;
		clearSectionButton.label.color = FlxColor.WHITE;
		
		check_notesSec = new FlxUICheckBox(10, clearSectionButton.y + 25, null, null, "Notes", 100);
		check_notesSec.checked = true;
		check_eventsSec = new FlxUICheckBox(check_notesSec.x + 100, check_notesSec.y, null, null, "Events", 100);
		check_eventsSec.checked = true;

		var swapSection:FlxButton = new FlxButton(10, check_notesSec.y + 40, "Swap section", function()
		{
			for (i in 0..._song.notes[curSec].sectionNotes.length)
			{
				var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
				note[1] = (note[1] + 4) % 8;
				_song.notes[curSec].sectionNotes[i] = note;
			}
			updateGrid();
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
		});

		var stepperCopy:FlxUINumericStepper = null;
		var copyLastButton:FlxButton = new FlxButton(10, swapSection.y + 30, "Copy last section", function()
		{
			var value:Int = Std.int(stepperCopy.value);
			if(value == 0) return;

			var daSec = FlxMath.maxInt(curSec, value);

			for (note in _song.notes[daSec - value].sectionNotes)
			{
				var strum = note[0] + Conductor.stepCrochet * (getSectionBeats(daSec) * 4 * value);

				var copiedNote:Array<Dynamic> = [strum, note[1], note[2], note[3]];
				_song.notes[daSec].sectionNotes.push(copiedNote);
			}

			var startThing:Float = sectionStartTime(-value);
			var endThing:Float = sectionStartTime(-value + 1);
			for (event in _song.events)
			{
				var strumTime:Float = event[0];
				if(endThing > event[0] && event[0] >= startThing)
				{
					strumTime += Conductor.stepCrochet * (getSectionBeats(daSec) * 4 * value);
					var copiedEventArray:Array<Dynamic> = [];
					for (i in 0...event[1].length)
					{
						var eventToPush:Array<Dynamic> = event[1][i];
						copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2], eventToPush[3], eventToPush[4], eventToPush[5], eventToPush[6], eventToPush[7], eventToPush[8], eventToPush[9],
							eventToPush[10], eventToPush[11], eventToPush[12], eventToPush[13], eventToPush[14]
						]);
					}
					_song.events.push([strumTime, copiedEventArray]);
				}
			}
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			updateGrid();
		});
		copyLastButton.setGraphicSize(80, 30);
		copyLastButton.updateHitbox();
		
		stepperCopy = new FlxUINumericStepper(copyLastButton.x + 100, copyLastButton.y, 1, 1, -999, 999, 0);
		blockPressWhileTypingOnStepper.push(stepperCopy);

		var duetButton:FlxButton = new FlxButton(10, copyLastButton.y + 45, "Duet Notes", function()
		{
			var duetNotes:Array<Array<Dynamic>> = [];
			for (note in _song.notes[curSec].sectionNotes)
			{
				var boob = note[1];
				if (boob > 3){
					boob -= 4;
				}else{
					boob += 4;
				}

				var copiedNote:Array<Dynamic> = [note[0], boob, note[2], note[3]];
				duetNotes.push(copiedNote);
			}

			for (i in duetNotes){
			_song.notes[curSec].sectionNotes.push(i);

			}
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			updateGrid();
		});
		var mirrorButton:FlxButton = new FlxButton(duetButton.x + 100, duetButton.y, "Mirror Notes", function()
		{
			var duetNotes:Array<Array<Dynamic>> = [];
			for (note in _song.notes[curSec].sectionNotes)
			{
				var boob = note[1]%4;
				boob = 3 - boob;
				if (note[1] > 3) boob += 4;

				note[1] = boob;
				var copiedNote:Array<Dynamic> = [note[0], boob, note[2], note[3]];
				//duetNotes.push(copiedNote);
			}

			for (i in duetNotes){
			//_song.notes[curSec].sectionNotes.push(i);

			}
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			updateGrid();
		});

		tab_group_section.add(new FlxText(stepperBeats.x, stepperBeats.y - 15, 0, 'Beats per Section:'));
		tab_group_section.add(new FlxText(stepperDType.x + 60, stepperDType.y,'Section dType'));
		tab_group_section.add(stepperBeats);
		tab_group_section.add(stepperSectionBPM);
		tab_group_section.add(stepperDType);
		tab_group_section.add(jumpSectionButton);
		tab_group_section.add(stepperSection);
		tab_group_section.add(check_mustHitSection);
		tab_group_section.add(check_gfSection);
		tab_group_section.add(check_playerAltAnim);
		tab_group_section.add(check_CPUAltAnim);
		tab_group_section.add(check_altAnim);
		tab_group_section.add(check_player4Section);
		tab_group_section.add(check_changeBPM);
		tab_group_section.add(copyButton);
		tab_group_section.add(pasteButton);
		tab_group_section.add(clearSectionButton);
		tab_group_section.add(check_notesSec);
		tab_group_section.add(check_eventsSec);
		tab_group_section.add(swapSection);
		tab_group_section.add(stepperCopy);
		tab_group_section.add(copyLastButton);
		tab_group_section.add(duetButton);
		tab_group_section.add(mirrorButton);

		UI_box.addGroup(tab_group_section);
	}

	var stepperSusLength:FlxUINumericStepper;
	var strumTimeInputText:FlxUIInputText; //I wanted to use a stepper but we can't scale these as far as i know :(
	var noteTypeDropDown:FlxUIDropDownMenu;
	var currentType:Int = 0;

	function addNoteUI():Void
	{
		var tab_group_note = new FlxUI(null, UI_box);
		tab_group_note.name = 'Note';

		stepperSusLength = new FlxUINumericStepper(10, 25, Conductor.stepCrochet / 2, 0, 0, Conductor.stepCrochet * 64);
		stepperSusLength.value = 0;
		stepperSusLength.name = 'note_susLength';
		blockPressWhileTypingOnStepper.push(stepperSusLength);

		strumTimeInputText = new FlxUIInputText(10, 65, 180, "0");
		tab_group_note.add(strumTimeInputText);
		blockPressWhileTypingOn.push(strumTimeInputText);

		var key:Int = 0;
		while (key < noteTypeList.length) {
			curNoteTypes.push(noteTypeList[key]);
			key++;
		}

		#if sys
		var foldersToCheck:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'custom_notetypes/');
		for (folder in foldersToCheck)
			for (file in FileSystem.readDirectory(folder))
			{
				var fileName:String = file.toLowerCase();
				var wordLen:Int = 4;
				if((#if LUA_ALLOWED fileName.endsWith('.lua') || #end
					#if HSCRIPT_ALLOWED checkForHScriptExtens(wordLen, fileName) || #end
					fileName.endsWith('.txt')) && fileName != 'readme.txt')
				{
					var fileToCheck:String = file.substr(0, file.length - wordLen);
					if(!curNoteTypes.contains(fileToCheck))
					{
						curNoteTypes.push(fileToCheck);
						key++;
					}
				}
			}
		#end


		var displayNameList:Array<String> = curNoteTypes.copy();
		for (i in 1...displayNameList.length) {
			displayNameList[i] = i + '. ' + displayNameList[i];
		}

		noteTypeDropDown = new FlxUIDropDownMenu(10, 105, FlxUIDropDownMenu.makeStrIdLabelArray(displayNameList, true), function(character:String)
		{
			currentType = Std.parseInt(character);
			if(curSelectedNote != null && curSelectedNote[1] > -1) {
				curSelectedNote[3] = curNoteTypes[currentType];
				updateGrid();
			}
		});
		blockPressWhileScrolling.push(noteTypeDropDown);

		tab_group_note.add(new FlxText(10, 10, 0, 'Sustain length:'));
		tab_group_note.add(new FlxText(10, 50, 0, 'Strum time (in miliseconds):'));
		tab_group_note.add(new FlxText(10, 90, 0, 'Note type:'));
		tab_group_note.add(stepperSusLength);
		tab_group_note.add(strumTimeInputText);
		tab_group_note.add(noteTypeDropDown);

		UI_box.addGroup(tab_group_note);
	}

	#if HSCRIPT_ALLOWED
	function checkForHScriptExtens(wordLen:Int, file:String):Bool
	{
		return ((file.endsWith('.hx') && (wordLen = 3) == 3) || (file.endsWith('.hscript') && (wordLen = 8) == 8) || 
			file.endsWith('.hsc') || file.endsWith('.hxs')
		);
	}
	#end

	var eventDropDown:FlxUIDropDownMenu;
	var descText:FlxText;
	var selectedEventText:FlxText;
	function addEventsUI():Void
	{
		var tab_group_event = new FlxUI(null, UI_box2);
		tab_group_event.name = 'Events';

		#if LUA_ALLOWED
		var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();
		var directories:Array<String> = [];

		#if MODS_ALLOWED
		directories.push(Paths.mods('custom_events/'));
		directories.push(Paths.mods(Mods.currentModDirectory + '/custom_events/'));
		for(mod in Mods.getGlobalMods())
			directories.push(Paths.mods(mod + '/custom_events/'));
		#end

		for (i in 0...directories.length) {
			var directory:String =  directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file != 'readme.txt' && file.endsWith('.txt')) {
						var fileToCheck:String = file.substr(0, file.length - 4);
						if(!eventPushedMap.exists(fileToCheck)) {
							eventPushedMap.set(fileToCheck, true);
							eventStuff.push([fileToCheck, File.getContent(path)]);
						}
					}
				}
			}
		}
		eventPushedMap.clear();
		eventPushedMap = null;
		#end

		descText = new FlxText(400, 800, 800, eventStuff[0][0], 8);

		var leEvents:Array<String> = [];
		for (i in 0...eventStuff.length) {
			leEvents.push(eventStuff[i][0]);
		}

		var text:FlxText = new FlxText(20, 30, 0, "Event:");
		tab_group_event.add(text);
		eventDropDown = new FlxUIDropDownMenu(20, 50, FlxUIDropDownMenu.makeStrIdLabelArray(leEvents, true), function(pressed:String) {
			var selectedEvent:Int = Std.parseInt(pressed);
			descText.text = eventStuff[selectedEvent][1];
			if (curSelectedNote != null &&  eventStuff != null) {
				if (curSelectedNote != null && curSelectedNote[2] == null){
					curSelectedNote[1][curEventSelected][0] = eventStuff[selectedEvent][0];
				}
				updateGrid();
			}
		});
		blockPressWhileScrolling.push(eventDropDown);

		//group 1

		var text:FlxText = new FlxText(20, 90, 0, "Value 1:");
		tab_group_event.add(text);
		value1InputText = new FlxUIInputText(20, 110, 100, "");
		blockPressWhileTypingOn.push(value1InputText);

		var text:FlxText = new FlxText(20, 130, 0, "Value 2:");
		tab_group_event.add(text);
		value2InputText = new FlxUIInputText(20, 150, 100, "");
		blockPressWhileTypingOn.push(value2InputText);

		var text:FlxText = new FlxText(20, 170, 0, "Value 3:");
		tab_group_event.add(text);
		value3InputText = new FlxUIInputText(20, 190, 100, "");
		blockPressWhileTypingOn.push(value3InputText);

		var text:FlxText = new FlxText(20, 210, 0, "Value 4:");
		tab_group_event.add(text);
		value4InputText = new FlxUIInputText(20, 230, 100, "");
		blockPressWhileTypingOn.push(value4InputText);

		var text:FlxText = new FlxText(20, 250, 0, "Value 5:");
		tab_group_event.add(text);
		value5InputText = new FlxUIInputText(20, 270, 100, "");
		blockPressWhileTypingOn.push(value5InputText);

		var text:FlxText = new FlxText(20, 290, 0, "Value 6:");
		tab_group_event.add(text);
		value6InputText = new FlxUIInputText(20, 310, 100, "");
		blockPressWhileTypingOn.push(value6InputText);

		//group 2

		var text:FlxText = new FlxText(140, 90, 0, "Value 7:");
		tab_group_event.add(text);
		value7InputText = new FlxUIInputText(140, 110, 100, "");
		blockPressWhileTypingOn.push(value7InputText);

		var text:FlxText = new FlxText(140, 130, 0, "Value 8:");
		tab_group_event.add(text);
		value8InputText = new FlxUIInputText(140, 150, 100, "");
		blockPressWhileTypingOn.push(value8InputText);

		var text:FlxText = new FlxText(140, 170, 0, "Value 9:");
		tab_group_event.add(text);
		value9InputText = new FlxUIInputText(140, 190, 100, "");
		blockPressWhileTypingOn.push(value9InputText);

		var text:FlxText = new FlxText(140, 210, 0, "Value 10:");
		tab_group_event.add(text);
		value10InputText = new FlxUIInputText(140, 230, 100, "");
		blockPressWhileTypingOn.push(value10InputText);

		var text:FlxText = new FlxText(140, 250, 0, "Value 11:");
		tab_group_event.add(text);
		value11InputText = new FlxUIInputText(140, 270, 100, "");
		blockPressWhileTypingOn.push(value11InputText);

		var text:FlxText = new FlxText(140, 290, 0, "Value 12:");
		tab_group_event.add(text);
		value12InputText = new FlxUIInputText(140, 310, 100, "");
		blockPressWhileTypingOn.push(value12InputText);

		//group 3

		var text:FlxText = new FlxText(260, 250, 0, "Value 13:");
		tab_group_event.add(text);
		value13InputText = new FlxUIInputText(260, 270, 100, "");
		blockPressWhileTypingOn.push(value13InputText);

		var text:FlxText = new FlxText(260, 290, 0, "Value 14:");
		tab_group_event.add(text);
		value14InputText = new FlxUIInputText(260, 310, 100, "");
		blockPressWhileTypingOn.push(value14InputText);

		descText.x = value6InputText.x;
		descText.y = value6InputText.y + 50;

		// New event buttons
		var removeButton:FlxButton = new FlxButton(eventDropDown.x + eventDropDown.width + 10, eventDropDown.y, '-', function()
		{
			if(curSelectedNote != null && curSelectedNote[2] == null) //Is event note
			{
				if(curSelectedNote[1].length < 2)
				{
					_song.events.remove(curSelectedNote);
					curSelectedNote = null;
				}
				else
				{
					curSelectedNote[1].remove(curSelectedNote[1][curEventSelected]);
				}

				var eventsGroup:Array<Dynamic>;
				--curEventSelected;
				if(curEventSelected < 0) curEventSelected = 0;
				else if(curSelectedNote != null && curEventSelected >= (eventsGroup = curSelectedNote[1]).length) curEventSelected = eventsGroup.length - 1;

				changeEventSelected();
				updateGrid();
			}
		});
		removeButton.setGraphicSize(Std.int(removeButton.height), Std.int(removeButton.height));
		removeButton.updateHitbox();
		removeButton.color = FlxColor.RED;
		removeButton.label.color = FlxColor.WHITE;
		removeButton.label.size = 12;
		setAllLabelsOffset(removeButton, -30, 0);
		tab_group_event.add(removeButton);

		var addButton:FlxButton = new FlxButton(removeButton.x + removeButton.width + 10, removeButton.y, '+', function()
		{
			if(curSelectedNote != null && curSelectedNote[2] == null) //Is event note
			{
				var eventsGroup:Array<Dynamic> = curSelectedNote[1];
				//main event, value1, value 2, etc...
				eventsGroup.push(['', '', '', '', '', '', '', '', '', '', '', '', '', '', '']);

				changeEventSelected(1);
				updateGrid();
			}
		});
		addButton.setGraphicSize(Std.int(removeButton.width), Std.int(removeButton.height));
		addButton.updateHitbox();
		addButton.color = FlxColor.GREEN;
		addButton.label.color = FlxColor.WHITE;
		addButton.label.size = 12;
		setAllLabelsOffset(addButton, -30, 0);
		tab_group_event.add(addButton);

		var moveLeftButton:FlxButton = new FlxButton(addButton.x + addButton.width + 20, addButton.y, '<', function()
		{
			changeEventSelected(-1);
		});
		moveLeftButton.setGraphicSize(Std.int(addButton.width), Std.int(addButton.height));
		moveLeftButton.updateHitbox();
		moveLeftButton.label.size = 12;
		setAllLabelsOffset(moveLeftButton, -30, 0);
		tab_group_event.add(moveLeftButton);

		var moveRightButton:FlxButton = new FlxButton(moveLeftButton.x + moveLeftButton.width + 10, moveLeftButton.y, '>', function()
		{
			changeEventSelected(1);
		});
		moveRightButton.setGraphicSize(Std.int(moveLeftButton.width), Std.int(moveLeftButton.height));
		moveRightButton.updateHitbox();
		moveRightButton.label.size = 12;
		setAllLabelsOffset(moveRightButton, -30, 0);
		tab_group_event.add(moveRightButton);

		selectedEventText = new FlxText(addButton.x - 100, addButton.y + addButton.height + 6, (moveRightButton.x - addButton.x) + 186, 'Selected Event: None');
		selectedEventText.alignment = CENTER;
		tab_group_event.add(selectedEventText);

		tab_group_event.add(descText);
		tab_group_event.add(value1InputText);
		tab_group_event.add(value2InputText);
		tab_group_event.add(value3InputText);
		tab_group_event.add(value4InputText);
		tab_group_event.add(value5InputText);
		tab_group_event.add(value6InputText);
		tab_group_event.add(value7InputText);
		tab_group_event.add(value8InputText);
		tab_group_event.add(value9InputText);
		tab_group_event.add(value10InputText);
		tab_group_event.add(value11InputText);
		tab_group_event.add(value12InputText);
		tab_group_event.add(value13InputText);
		tab_group_event.add(value14InputText);
		tab_group_event.add(eventDropDown);

		UI_box2.addGroup(tab_group_event);
	}

	function changeEventSelected(change:Int = 0)
	{
		if(curSelectedNote != null && curSelectedNote[2] == null) //Is event note
		{
			curEventSelected += change;
			if(curEventSelected < 0) curEventSelected = Std.int(curSelectedNote[1].length) - 1;
			else if(curEventSelected >= curSelectedNote[1].length) curEventSelected = 0;
			selectedEventText.text = 'Selected Event: ' + (curEventSelected + 1) + ' / ' + curSelectedNote[1].length;
		}
		else
		{
			curEventSelected = 0;
			selectedEventText.text = 'Selected Event: None';
		}
		updateNoteUI();
	}

	function setAllLabelsOffset(button:FlxButton, x:Float, y:Float)
	{
		for (point in button.labelOffsets)
		{
			point.set(x, y);
		}
	}

	var metronome:FlxUICheckBox;
	var mouseScrollingQuant:FlxUICheckBox;
	var metronomeStepper:FlxUINumericStepper;
	var metronomeOffsetStepper:FlxUINumericStepper;
	var disableAutoScrolling:FlxUICheckBox;
	var instVolume:FlxUINumericStepper;
	var voicesVolume:FlxUINumericStepper;
	var voicesOppVolume:FlxUINumericStepper;
	function addChartingUI() {
		var tab_group_chart = new FlxUI(null, UI_box);
		tab_group_chart.name = 'Charting';

		#if desktop
		if (FlxG.save.data.chart_waveformInst == null) FlxG.save.data.chart_waveformInst = false;
		if (FlxG.save.data.chart_waveformVoices == null) FlxG.save.data.chart_waveformVoices = false;
		if (FlxG.save.data.chart_waveformOppVoices == null) FlxG.save.data.chart_waveformOppVoices = false;

		var waveformUseInstrumental:FlxUICheckBox = null;
		var waveformUseVoices:FlxUICheckBox = null;
		var waveformUseOppVoices:FlxUICheckBox = null;

		waveformUseInstrumental = new FlxUICheckBox(10, 90, null, null, "Waveform\n(Instrumental)", 85);
		waveformUseInstrumental.checked = FlxG.save.data.chart_waveformInst;
		waveformUseInstrumental.callback = function()
		{
			waveformUseVoices.checked = false;
			waveformUseOppVoices.checked = false;
			FlxG.save.data.chart_waveformVoices = false;
			FlxG.save.data.chart_waveformOppVoices = false;
			FlxG.save.data.chart_waveformInst = waveformUseInstrumental.checked;
			updateWaveform();
		};

		waveformUseVoices = new FlxUICheckBox(waveformUseInstrumental.x + 100, waveformUseInstrumental.y, null, null, "Waveform\n(Main Vocals)", 85);
		waveformUseVoices.checked = FlxG.save.data.chart_waveformVoices && !waveformUseInstrumental.checked;
		waveformUseVoices.callback = function()
		{
			waveformUseInstrumental.checked = false;
			waveformUseOppVoices.checked = false;
			FlxG.save.data.chart_waveformInst = false;
			FlxG.save.data.chart_waveformOppVoices = false;
			FlxG.save.data.chart_waveformVoices = waveformUseVoices.checked;
			updateWaveform();
		};

		waveformUseOppVoices = new FlxUICheckBox(waveformUseInstrumental.x + 200, waveformUseInstrumental.y, null, null, "Waveform\n(Opp. Vocals)", 85);
		waveformUseOppVoices.checked = FlxG.save.data.chart_waveformOppVoices && !waveformUseVoices.checked;
		waveformUseOppVoices.callback = function()
		{
			waveformUseInstrumental.checked = false;
			waveformUseVoices.checked = false;
			FlxG.save.data.chart_waveformInst = false;
			FlxG.save.data.chart_waveformVoices = false;
			FlxG.save.data.chart_waveformOppVoices = waveformUseOppVoices.checked;
			updateWaveform();
		};
		#end

		check_mute_inst = new FlxUICheckBox(10, 280, null, null, "Mute Instrumental (in editor)", 100);
		check_mute_inst.checked = false;
		check_mute_inst.callback = function()
		{
			var vol:Float = instVolume.value;

			if (check_mute_inst.checked)
				vol = 0;

			FlxG.sound.music.volume = vol;
		};
		mouseScrollingQuant = new FlxUICheckBox(10, 200, null, null, "Mouse Scrolling Quantization", 100);
		if (FlxG.save.data.mouseScrollingQuant == null) FlxG.save.data.mouseScrollingQuant = false;
		mouseScrollingQuant.checked = FlxG.save.data.mouseScrollingQuant;

		mouseScrollingQuant.callback = function()
		{
			FlxG.save.data.mouseScrollingQuant = mouseScrollingQuant.checked;
			mouseQuant = FlxG.save.data.mouseScrollingQuant;
		};

		check_vortex = new FlxUICheckBox(10, 160, null, null, "Vortex Editor (BETA)", 100);
		if (FlxG.save.data.chart_vortex == null) FlxG.save.data.chart_vortex = false;
		check_vortex.checked = FlxG.save.data.chart_vortex;

		check_vortex.callback = function()
		{
			FlxG.save.data.chart_vortex = check_vortex.checked;
			vortex = FlxG.save.data.chart_vortex;
			reloadGridLayer();
		};

		check_warnings = new FlxUICheckBox(10, 120, null, null, "Ignore Progress Warnings", 100);
		if (FlxG.save.data.ignoreWarnings == null) FlxG.save.data.ignoreWarnings = false;
		check_warnings.checked = FlxG.save.data.ignoreWarnings;

		check_warnings.callback = function()
		{
			FlxG.save.data.ignoreWarnings = check_warnings.checked;
			ignoreWarnings = FlxG.save.data.ignoreWarnings;
		};

		check_mute_vocals = new FlxUICheckBox(check_mute_inst.x, check_mute_inst.y + 30, null, null, "Mute Main Vocals (in editor)", 100);
		check_mute_vocals.checked = false;
		check_mute_vocals.callback = function()
		{
			var vol:Float = voicesVolume.value;
			if (check_mute_vocals.checked)
				vol = 0;
			if(vocals != null) vocals.volume = vol;
		};
		check_mute_vocals_opponent = new FlxUICheckBox(check_mute_vocals.x + 120, check_mute_vocals.y, null, null, "Mute Opp. Vocals (in editor)", 100);
		check_mute_vocals_opponent.checked = false;
		check_mute_vocals_opponent.callback = function()
		{
			var vol:Float = voicesOppVolume.value;
			if (check_mute_vocals_opponent.checked)
				vol = 0;

			if(opponentVocals != null) opponentVocals.volume = vol;
		};

		playSoundBf = new FlxUICheckBox(check_mute_inst.x, check_mute_vocals.y + 30, null, null, 'Play Sound (Boyfriend notes)', 100,
			function() {
				FlxG.save.data.chart_playSoundBf = playSoundBf.checked;
			}
		);
		if (FlxG.save.data.chart_playSoundBf == null) FlxG.save.data.chart_playSoundBf = false;
		playSoundBf.checked = FlxG.save.data.chart_playSoundBf;

		playSoundDad = new FlxUICheckBox(check_mute_inst.x + 120, playSoundBf.y, null, null, 'Play Sound (Opponent notes)', 100,
			function() {
				FlxG.save.data.chart_playSoundDad = playSoundDad.checked;
			}
		);
		if (FlxG.save.data.chart_playSoundDad == null) FlxG.save.data.chart_playSoundDad = false;
		playSoundDad.checked = FlxG.save.data.chart_playSoundDad;

		metronome = new FlxUICheckBox(10, 15, null, null, "Metronome Enabled", 100,
			function() {
				FlxG.save.data.chart_metronome = metronome.checked;
			}
		);
		if (FlxG.save.data.chart_metronome == null) FlxG.save.data.chart_metronome = false;
		metronome.checked = FlxG.save.data.chart_metronome;

		metronomeStepper = new FlxUINumericStepper(15, 55, 5, _song.bpm, 1, 1500, 1);
		metronomeOffsetStepper = new FlxUINumericStepper(metronomeStepper.x + 100, metronomeStepper.y, 25, 0, 0, 1000, 1);
		blockPressWhileTypingOnStepper.push(metronomeStepper);
		blockPressWhileTypingOnStepper.push(metronomeOffsetStepper);

		disableAutoScrolling = new FlxUICheckBox(metronome.x + 120, metronome.y, null, null, "Disable Autoscroll (Not Recommended)", 120,
			function() {
				FlxG.save.data.chart_noAutoScroll = disableAutoScrolling.checked;
			}
		);
		if (FlxG.save.data.chart_noAutoScroll == null) FlxG.save.data.chart_noAutoScroll = false;
		disableAutoScrolling.checked = FlxG.save.data.chart_noAutoScroll;

		instVolume = new FlxUINumericStepper(metronomeStepper.x, 250, 0.1, 1, 0, 1, 1);
		instVolume.value = FlxG.sound.music.volume;
		instVolume.name = 'inst_volume';
		blockPressWhileTypingOnStepper.push(instVolume);

		voicesVolume = new FlxUINumericStepper(instVolume.x + 100, instVolume.y, 0.1, 1, 0, 1, 1);
		voicesVolume.value = vocals.volume;
		voicesVolume.name = 'voices_volume';
		blockPressWhileTypingOnStepper.push(voicesVolume);

		voicesOppVolume = new FlxUINumericStepper(instVolume.x + 200, instVolume.y, 0.1, 1, 0, 1, 1);
		voicesOppVolume.value = vocals.volume;
		voicesOppVolume.name = 'voices_opp_volume';
		blockPressWhileTypingOnStepper.push(voicesOppVolume);
		
		#if FLX_PITCH
		sliderRate = new FlxUISlider(this, 'playbackSpeed', 120, 120, 0.1, 3, 150, null, 5, FlxColor.WHITE, FlxColor.BLACK);
		sliderRate.nameLabel.text = 'Playback Rate';
		tab_group_chart.add(sliderRate);
		#end

		tab_group_chart.add(new FlxText(metronomeStepper.x, metronomeStepper.y - 15, 0, 'BPM:'));
		tab_group_chart.add(new FlxText(metronomeOffsetStepper.x, metronomeOffsetStepper.y - 15, 0, 'Offset (ms):'));
		tab_group_chart.add(new FlxText(instVolume.x, instVolume.y - 15, 0, 'Inst Volume'));
		tab_group_chart.add(new FlxText(voicesVolume.x, voicesVolume.y - 15, 0, 'Main Vocals'));
		tab_group_chart.add(new FlxText(voicesOppVolume.x, voicesOppVolume.y - 15, 0, 'Opp. Vocals'));
		tab_group_chart.add(metronome);
		tab_group_chart.add(disableAutoScrolling);
		tab_group_chart.add(metronomeStepper);
		tab_group_chart.add(metronomeOffsetStepper);
		#if desktop
		tab_group_chart.add(waveformUseInstrumental);
		tab_group_chart.add(waveformUseVoices);
		tab_group_chart.add(waveformUseOppVoices);
		#end
		tab_group_chart.add(instVolume);
		tab_group_chart.add(voicesVolume);
		tab_group_chart.add(voicesOppVolume);
		tab_group_chart.add(check_mute_inst);
		tab_group_chart.add(check_mute_vocals);
		tab_group_chart.add(check_mute_vocals_opponent);
		tab_group_chart.add(check_vortex);
		tab_group_chart.add(mouseScrollingQuant);
		tab_group_chart.add(check_warnings);
		tab_group_chart.add(playSoundBf);
		tab_group_chart.add(playSoundDad);
		UI_box.addGroup(tab_group_chart);
	}

	var gameOverCharacterInputText:FlxUIInputText;
	var gameOverSoundInputText:FlxUIInputText;
	var gameOverLoopInputText:FlxUIInputText;
	var gameOverEndInputText:FlxUIInputText;
	var noteSkinInputText:FlxUIInputText;
	var noteSplashesInputText:FlxUIInputText;
	function addDataUI()
	{
		var tab_group_data = new FlxUI(null, UI_box2);
		tab_group_data.name = 'Data';

		//
		gameOverCharacterInputText = new FlxUIInputText(10, 25, 150, _song.gameOverChar != null ? _song.gameOverChar : '', 8);
		blockPressWhileTypingOn.push(gameOverCharacterInputText);

		gameOverSoundInputText = new FlxUIInputText(10, gameOverCharacterInputText.y + 35, 150, _song.gameOverSound != null ? _song.gameOverSound : '', 8);
		blockPressWhileTypingOn.push(gameOverSoundInputText);

		gameOverLoopInputText = new FlxUIInputText(10, gameOverSoundInputText.y + 35, 150, _song.gameOverLoop != null ? _song.gameOverLoop : '', 8);
		blockPressWhileTypingOn.push(gameOverLoopInputText);

		gameOverEndInputText = new FlxUIInputText(10, gameOverLoopInputText.y + 35, 150, _song.gameOverEnd != null ? _song.gameOverEnd : '', 8);
		blockPressWhileTypingOn.push(gameOverEndInputText);
		//

		#if MODS_ALLOWED
		var directories:Array<String> = [Paths.mods('data/characters/'), Paths.mods(Mods.currentModDirectory + '/data/characters/'), Paths.getSharedPath('data/characters/')];
		for(mod in Mods.getGlobalMods())
			directories.push(Paths.mods(mod + '/characters/'));
		#else
		var directories:Array<String> = [Paths.getSharedPath('data/characters/')];
		#end

		var tempArray:Array<String> = [];
		var characters:Array<String> = Mods.mergeAllTextsNamed('data/characterList.txt', Paths.getSharedPath());
		for (character in characters)
		{
			if(character.trim().length > 0)
				tempArray.push(character);
		}

		#if MODS_ALLOWED
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json')) {
						var charToCheck:String = file.substr(0, file.length - 5);
						if(charToCheck.trim().length > 0 && !charToCheck.endsWith('-dead') && !tempArray.contains(charToCheck)) {
							tempArray.push(charToCheck);
							characters.push(charToCheck);
						}
					}
				}
			}
		}
		#end

		var player1DropDown = new FlxUIDropDownMenu(gameOverEndInputText.x + 320, gameOverCharacterInputText.y, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player1 = characters[Std.parseInt(character)];
			updateJsonData();
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			updateHeads();
		});
		player1DropDown.selectedLabel = _song.player1;
		blockPressWhileScrolling.push(player1DropDown);

		var gfVersionDropDown = new FlxUIDropDownMenu(player1DropDown.x, player1DropDown.y + 40, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.gfVersion = characters[Std.parseInt(character)];
			updateJsonData();
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			updateHeads();
		});
		gfVersionDropDown.selectedLabel = _song.gfVersion;
		blockPressWhileScrolling.push(gfVersionDropDown);

		var player2DropDown = new FlxUIDropDownMenu(player1DropDown.x, gfVersionDropDown.y + 40, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player2 = characters[Std.parseInt(character)];
			updateJsonData();
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			updateHeads();
		});
		player2DropDown.selectedLabel = _song.player2;
		blockPressWhileScrolling.push(player2DropDown);

		var player4DropDown = new FlxUIDropDownMenu(player1DropDown.x, player2DropDown.y + 40, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player4 = characters[Std.parseInt(character)];
			updateJsonData();
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			updateHeads();
		});
		player4DropDown.selectedLabel = _song.player4;
		blockPressWhileScrolling.push(player4DropDown);

		#if MODS_ALLOWED
		var directories:Array<String> = [Paths.mods('stages/'), Paths.mods(Mods.currentModDirectory + '/stages/'), Paths.getSharedPath('stages/')];
		for(mod in Mods.getGlobalMods())
			directories.push(Paths.mods(mod + '/stages/'));
		#else
		var directories:Array<String> = [Paths.getSharedPath('stages/')];
		#end

		var stageFile:Array<String> = Mods.mergeAllTextsNamed('data/stageList.txt', Paths.getSharedPath());
		var stages:Array<String> = [];
		for (stage in stageFile) {
			if(stage.trim().length > 0) {
				stages.push(stage);
			}
			tempArray.push(stage);
		}
		#if MODS_ALLOWED
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json')) {
						var stageToCheck:String = file.substr(0, file.length - 5);
						if(stageToCheck.trim().length > 0 && !tempArray.contains(stageToCheck)) {
							tempArray.push(stageToCheck);
							stages.push(stageToCheck);
						}
					}
				}
			}
		}
		#end

		if(stages.length < 1) stages.push('stage');

		stageDropDown = new FlxUIDropDownMenu(player1DropDown.x + 140, player1DropDown.y, FlxUIDropDownMenu.makeStrIdLabelArray(stages, true), function(character:String)
		{
			_song.stage = stages[Std.parseInt(character)];
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
		});
		stageDropDown.selectedLabel = _song.stage;
		blockPressWhileScrolling.push(stageDropDown);

		// Checks if all difficulties json files exists and removes difficulties that dont have a json file.
		var availableDifficulties:Array<Int> = [];
		var availableDifficultiesTexts:Array<String> = [];

		for(i in 0...Difficulty.list.length){
			var jsonInput:String;
			if(Difficulty.list[i].toLowerCase() == 'normal') jsonInput = _song.songId.toLowerCase();
			else jsonInput = _song.songId.toLowerCase() + "-" + Difficulty.list[i];

			var folder:String = _song.songId.toLowerCase();
			var formattedFolder:String = Paths.formatToSongPath(folder);
			var formattedSong:String = Paths.formatToSongPath(jsonInput);

			var pathExists:Bool = (Paths.fileExists('data/songs/' + formattedFolder + '/' + formattedSong + '.json', BINARY) || Paths.fileExists('shared/data/songs/' + formattedFolder + '/' + formattedSong + '.json', BINARY));
			if(pathExists == true){
				availableDifficulties.push(i);
				availableDifficultiesTexts.push(Difficulty.list[i]);
			}
		}

		if(availableDifficulties == null || availableDifficulties.length <= 0){
			Debug.logTrace('Where are the difficulties...?');
			availableDifficulties.push(PlayState.storyDifficulty);
			availableDifficultiesTexts.push(Difficulty.list[0]);
		}

		difficultyDropDown = new FlxUIDropDownMenu(stageDropDown.x, stageDropDown.y + 40, FlxUIDropDownMenu.makeStrIdLabelArray(availableDifficultiesTexts, true), function(pressed:String)
		{	
			var curSelected:Int = Std.parseInt(pressed);
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, function(){
				PlayState.storyDifficulty = availableDifficulties[curSelected];
				PlayState.changedDifficulty = true;
				loadJson(_song.songId.toLowerCase());
			}, null,ignoreWarnings));
		});		
		difficultyDropDown.selectedLabel = Difficulty.list[PlayState.storyDifficulty];
		blockPressWhileScrolling.push(difficultyDropDown);

		var check_disableNoteRGB:FlxUICheckBox = new FlxUICheckBox(10, 170, null, null, "Disable Note RGB", 100);
		check_disableNoteRGB.checked = (_song.disableNoteRGB == true);
		check_disableNoteRGB.callback = function()
		{
			_song.disableNoteRGB = check_disableNoteRGB.checked;
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			updateGrid();
			//Debug.logTrace('CHECKED!');
		};

		var check_disableNoteQuantRGB:FlxUICheckBox = new FlxUICheckBox(check_disableNoteRGB.x, check_disableNoteRGB.y + 20, null, null, "Disable Note Quant", 100);
		check_disableNoteQuantRGB.checked = (_song.disableNoteQuantRGB == true);
		check_disableNoteQuantRGB.callback = function()
		{
			_song.disableNoteQuantRGB = check_disableNoteQuantRGB.checked;
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			updateGrid();
			//Debug.logTrace('CHECKED!');
		};

		var check_disableStrumRGB:FlxUICheckBox = new FlxUICheckBox(check_disableNoteQuantRGB.x, check_disableNoteQuantRGB.y + 20, null, null, "Disable Strum RGB", 100);
		check_disableStrumRGB.checked = (_song.disableStrumRGB == true);
		check_disableStrumRGB.callback = function()
		{
			_song.disableStrumRGB = check_disableStrumRGB.checked;
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			updateGrid();
			//Debug.logTrace('CHECKED!');
		};

		var check_disableSplashRGB:FlxUICheckBox = new FlxUICheckBox(check_disableStrumRGB.x, check_disableStrumRGB.y + 20, null, null, "Disable Splash RGB", 100);
		check_disableSplashRGB.checked = (_song.disableSplashRGB == true);
		check_disableSplashRGB.callback = function()
		{
			_song.disableSplashRGB = check_disableSplashRGB.checked;
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			updateGrid();
			//Debug.logTrace('CHECKED!');
		};

		//
		noteSkinInputText = new FlxUIInputText(10, 280, 150, _song.arrowSkin, 8);
		blockPressWhileTypingOn.push(noteSkinInputText);

		noteSplashesInputText = new FlxUIInputText(noteSkinInputText.x, noteSkinInputText.y + 35, 150, _song.splashSkin != null ? _song.splashSkin : '', 8);
		blockPressWhileTypingOn.push(noteSplashesInputText);

		var reloadNotesButton:FlxButton = new FlxButton(noteSplashesInputText.x + 5, noteSplashesInputText.y + 20, 'Change Notes', function() {
			_song.arrowSkin = noteSkinInputText.text;
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			updateGrid();
		});
		//
	
		var usingHUD = new FlxUICheckBox(reloadNotesButton.x + 160, reloadNotesButton.y - 20, null, null, "usesHUD Cameras", 100);
		usingHUD.checked = _song.usesHUD;
		usingHUD.callback = function()
		{
			_song.usesHUD = usingHUD.checked;
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			//Debug.logInfo('CHECKED!');
		};

		var noIntroSkipping = new FlxUICheckBox(usingHUD.x, usingHUD.y - 20, null, null, "Doesn't Skip Intro", 100); //
		noIntroSkipping.checked = _song.noIntroSkip;
		noIntroSkipping.callback = function()
		{
			_song.noIntroSkip = noIntroSkipping.checked;
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			//Debug.logInfo('CHECKED!');
		};

		var notITGModchart = new FlxUICheckBox(noIntroSkipping.x, noIntroSkipping.y - 20, null, null, "NotITG modcharts", 100);
		notITGModchart.checked = _song.notITG;
		notITGModchart.callback = function()
		{
			_song.notITG = notITGModchart.checked;
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			//Debug.logInfo('CHECKED!');
		};

		var forceRightScroll = new FlxUICheckBox(notITGModchart.x, notITGModchart.y - 20, null, null, "Forced RightScroll", 100);
		forceRightScroll.checked = _song.rightScroll;
		forceRightScroll.callback = function()
		{
			_song.rightScroll = forceRightScroll.checked;
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
		};

		var forceMiddleScroll = new FlxUICheckBox(forceRightScroll.x, forceRightScroll.y - 20, null, null, "Forced MiddleScroll", 100);
		forceMiddleScroll.checked = _song.middleScroll;
		forceMiddleScroll.callback = function()
		{
			_song.middleScroll = forceMiddleScroll.checked;
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
		};

		var blockOpponentMode = new FlxUICheckBox(forceMiddleScroll.x, forceMiddleScroll.y - 20, null, null, "Block Opponent Mode", 100);
		blockOpponentMode.checked = _song.blockOpponentMode;
		blockOpponentMode.callback = function()
		{
			_song.blockOpponentMode = blockOpponentMode.checked;
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			//Debug.logInfo('CHECKED!');
		};

		var oldBarSystem = new FlxUICheckBox(blockOpponentMode.x, blockOpponentMode.y - 20, null, null, "Old Bar System", 100);
		oldBarSystem.checked = _song.oldBarSystem;
		oldBarSystem.callback = function()
		{
			_song.oldBarSystem = oldBarSystem.checked;
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			//Debug.logInfo('CHECKED!');
		};

		var disableCaching = new FlxUICheckBox(oldBarSystem.x, oldBarSystem.y - 20, null, null, "Disable Initial PlayState Caching", 100);
		disableCaching.checked = _song.disableStartCaching;
		disableCaching.callback = function()
		{
			_song.disableStartCaching = disableCaching.checked;
			hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			//Debug.logInfo('CHECKED!');
		};

		tab_group_data.add(gameOverCharacterInputText);
		tab_group_data.add(gameOverSoundInputText);
		tab_group_data.add(gameOverLoopInputText);
		tab_group_data.add(gameOverEndInputText);

		tab_group_data.add(check_disableNoteRGB);
		tab_group_data.add(check_disableNoteQuantRGB);
		tab_group_data.add(check_disableSplashRGB);
		tab_group_data.add(check_disableStrumRGB);

		tab_group_data.add(reloadNotesButton);
		tab_group_data.add(noIntroSkipping);
		tab_group_data.add(usingHUD);
		tab_group_data.add(forceMiddleScroll);
		tab_group_data.add(forceRightScroll);
		tab_group_data.add(notITGModchart);
		tab_group_data.add(blockOpponentMode);
		tab_group_data.add(oldBarSystem);
		tab_group_data.add(disableCaching);
		tab_group_data.add(noteSkinInputText);
		tab_group_data.add(noteSplashesInputText);

		tab_group_data.add(new FlxText(gameOverCharacterInputText.x, gameOverCharacterInputText.y - 15, 0, 'Game Over Character Name:'));
		tab_group_data.add(new FlxText(gameOverSoundInputText.x, gameOverSoundInputText.y - 15, 0, 'Game Over Death Sound (sounds/):'));
		tab_group_data.add(new FlxText(gameOverLoopInputText.x, gameOverLoopInputText.y - 15, 0, 'Game Over Loop Music (music/):'));
		tab_group_data.add(new FlxText(gameOverEndInputText.x, gameOverEndInputText.y - 15, 0, 'Game Over Retry Music (music/):'));

		tab_group_data.add(new FlxText(noteSkinInputText.x, noteSkinInputText.y - 15, 0, 'Note Texture:'));
		tab_group_data.add(new FlxText(noteSplashesInputText.x, noteSplashesInputText.y - 15, 0, 'Note Splashes Texture:'));

		tab_group_data.add(new FlxText(player4DropDown.x, player4DropDown.y - 15, 0, 'Player 4:'));
		tab_group_data.add(new FlxText(player2DropDown.x, player2DropDown.y - 15, 0, 'Opponent:'));
		tab_group_data.add(new FlxText(gfVersionDropDown.x, gfVersionDropDown.y - 15, 0, 'Girlfriend:'));
		tab_group_data.add(new FlxText(player1DropDown.x, player1DropDown.y - 15, 0, 'Boyfriend:'));
		tab_group_data.add(new FlxText(stageDropDown.x, stageDropDown.y - 15, 0, 'Stage:'));
		tab_group_data.add(new FlxText(difficultyDropDown.x, difficultyDropDown.y - 15, 0, 'Difficulty:'));
		tab_group_data.add(player4DropDown);
		tab_group_data.add(player2DropDown);
		tab_group_data.add(gfVersionDropDown);
		tab_group_data.add(player1DropDown);
		tab_group_data.add(difficultyDropDown);
		tab_group_data.add(stageDropDown);

		UI_box2.addGroup(tab_group_data);
	}

	function loadSong():Void
	{
		if (FlxG.sound.music != null) FlxG.sound.music.stop();
		if (vocals != null)
		{
			vocals.stop();
			vocals.destroy();
		}
		if (opponentVocals != null)
		{
			opponentVocals.stop();
			opponentVocals.destroy();
		}

		vocals = new FlxSound();
		try
		{
			#if SCEFEATURES_ALLOWED
			var normalVocals = Paths.voices((PlayState.SONG.vocalsPrefix != null ? PlayState.SONG.vocalsPrefix : ''), currentSongName, (PlayState.SONG.vocalsSuffix != null ? PlayState.SONG.vocalsSuffix : ''));
			var playerVocals = Paths.voices((PlayState.SONG.vocalsPrefix != null ? PlayState.SONG.vocalsPrefix : ''), currentSongName, (PlayState.SONG.vocalsSuffix != null ? PlayState.SONG.vocalsSuffix : ''), (characterData.vocalsP1 == null || characterData.vocalsP1.length < 1) ? '' : characterData.vocalsP1);
			vocals.loadEmbedded(playerVocals != null ?  playerVocals : normalVocals);
			#else
			var normalVocals = Paths.voices(currentSongName);
			var playerVocals = Paths.voices(currentSongName, (characterData.vocalsP1 == null || characterData.vocalsP1.length < 1) ? '' : characterData.vocalsP1);
			vocals.loadEmbedded(playerVocals != null ?  playerVocals : normalVocals);
			#end
		}
		catch(e:Dynamic){}
		vocals.autoDestroy = false;
		FlxG.sound.list.add(vocals);

		opponentVocals = new FlxSound();
		try
		{
			#if SCEFEATURES_ALLOWED
			var oppVocals = Paths.voices((PlayState.SONG.vocalsPrefix != null ? PlayState.SONG.vocalsPrefix : ''), currentSongName, (PlayState.SONG.vocalsSuffix != null ? PlayState.SONG.vocalsSuffix : ''), (characterData.vocalsP2 == null || characterData.vocalsP2.length < 1) ? 'Oppnent' : characterData.vocalsP2);
			if(oppVocals != null) opponentVocals.loadEmbedded(oppVocals);
			#else
			var oppVocals = Paths.voices(currentSongName, (characterData.vocalsP2 == null || characterData.vocalsP2.length < 1) ? 'Oppnent' : characterData.vocalsP2);
			if(oppVocals != null) opponentVocals.loadEmbedded(oppVocals);
			#end
		}
		catch(e:Dynamic){
			opponentVocals = null;
		}
		opponentVocals.autoDestroy = false;
		FlxG.sound.list.add(opponentVocals);
		generateSong();
		FlxG.sound.music.pause();
		Conductor.songPosition = sectionStartTime();
		FlxG.sound.music.time = Conductor.songPosition;

		var curTime:Float = 0;
		//Debug.logTrace(_song.notes.length);
		if(_song.notes.length <= 1) //First load ever
		{
			Debug.logTrace('first load ever!!');
			while(curTime < FlxG.sound.music.length)
			{
				addSection();
				curTime += (60 / _song.bpm) * 4000;
			}
		}
	}

	var playtesting:Bool = false;
	var playtestingTime:Float = 0;
	var playtestingOnComplete:Void->Void = null;
	override function closeSubState()
	{
		if(playtesting)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				FlxG.sound.music.time = playtestingTime;
				FlxG.sound.music.onComplete = playtestingOnComplete;
				if (instVolume != null) FlxG.sound.music.volume = instVolume.value;
				if (check_mute_inst != null && check_mute_inst.checked) FlxG.sound.music.volume = 0;
			}

			if(vocals != null)
			{
				vocals.pause();
				vocals.time = playtestingTime;
				if (voicesVolume != null) vocals.volume = voicesVolume.value;
				if (check_mute_vocals != null && check_mute_vocals.checked) vocals.volume = 0;
			}

			if(opponentVocals != null)
			{
				opponentVocals.pause();
				opponentVocals.time = playtestingTime;
				if (voicesOppVolume != null) opponentVocals.volume = voicesOppVolume.value;
				if (check_mute_vocals_opponent != null && check_mute_vocals_opponent.checked) opponentVocals.volume = 0;
			}

			#if DISCORD_ALLOWED
			// Updating Discord Rich Presence
			DiscordClient.changePresence("Chart Editor", StringTools.replace(_song.songId, '-', ' '));
			#end
		}
		super.closeSubState();
	}

	function generateSong() {
		#if SCEFEATURES_ALLOWED
		FlxG.sound.playMusic(Paths.inst((PlayState.SONG.instrumentalPrefix != null ? PlayState.SONG.instrumentalPrefix : ''), _song.song, (PlayState.SONG.instrumentalSuffix != null ? PlayState.SONG.instrumentalSuffix : '')), 1);
		#else
		FlxG.sound.playMusic(Paths.inst(_song.song));
		#end
		FlxG.sound.music.autoDestroy = false;
		if (instVolume != null) FlxG.sound.music.volume = instVolume.value;
		if (check_mute_inst != null && check_mute_inst.checked) FlxG.sound.music.volume = 0;

		FlxG.sound.music.onComplete = function()
		{
			FlxG.sound.music.pause();
			Conductor.songPosition = 0;
			if(vocals != null) {
				vocals.pause();
				vocals.time = 0;
			}
			if(opponentVocals != null) {
				opponentVocals.pause();
				opponentVocals.time = 0;
			}
			changeSection();
			curSec = 0;
			updateGrid();
			updateSectionUI();
			if (vocals != null) vocals.play();
			if (opponentVocals != null) opponentVocals.play();
		};
	}

	function generateUI():Void
	{
		while (bullshitUI.members.length > 0)
		{
			bullshitUI.remove(bullshitUI.members[0], true);
		}

		// general shit
		var title:FlxText = new FlxText(UI_box.x + 20, UI_box.y + 20, 0);
		bullshitUI.add(title);
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		if (id == FlxUICheckBox.CLICK_EVENT)
		{
			var check:FlxUICheckBox = cast sender;
			var label = check.getLabel().text;
			switch (label)
			{
				case 'Must hit section':
					_song.notes[curSec].mustHitSection = check.checked;
					hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
					updateGrid();
					updateHeads();

				case 'GF section':
					_song.notes[curSec].gfSection = check.checked;
					hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
					updateGrid();
					updateHeads();

				case "Player 4 Section":
					_song.notes[curSec].player4Section = check.checked;
					hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
					updateGrid();
					updateHeads();

				case 'Change BPM':
					_song.notes[curSec].changeBPM = check.checked;
					hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
					FlxG.log.add('changed bpm shit');
				case "Alt Animation":
					_song.notes[curSec].altAnim = check.checked;
					hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
				case "CPU Alternate Animation":
					_song.notes[curSec].CPUAltAnim = check.checked;
					hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
				case "Player Alternate Animation":
					_song.notes[curSec].playerAltAnim = check.checked;
					hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var nums:FlxUINumericStepper = cast sender;
			var wname = nums.name;
			//FlxG.log.add(wname);
			switch(wname)
			{
				case 'section_beats':
					hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
					_song.notes[curSec].sectionBeats = nums.value;
					reloadGridLayer();

				case 'song_speed':
					hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
					_song.speed = nums.value;

				case 'song_bpm':
					hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
					_song.bpm = nums.value;
					Conductor.mapBPMChanges(_song);
					Conductor.bpm = nums.value;
					stepperSusLength.stepSize = Math.ceil(Conductor.stepCrochet / 2);
					updateGrid();

				case 'note_susLength':
					if(curSelectedNote != null && curSelectedNote[2] != null) {
						curSelectedNote[2] = nums.value;
						hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
						updateGrid();
					}

				case 'section_bpm':
					hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
					_song.notes[curSec].bpm = nums.value;
					updateGrid();

				case 'inst_volume':
					hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
					FlxG.sound.music.volume = nums.value;
					if(check_mute_inst.checked) FlxG.sound.music.volume = 0;

				case 'voices_volume':
					hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
					vocals.volume = nums.value;
					if(check_mute_vocals.checked) vocals.volume = 0;

				case 'voices_opp_volume':
					if (opponentVocals != null)
					{
						opponentVocals.volume = nums.value;
						if(check_mute_vocals_opponent.checked) opponentVocals.volume = 0;
					}

				case 'section_dtype':
					hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
					_song.notes[curSec].dType = Std.int(nums.value);
					updateSectionUI();
					updateGrid();
			}
		}
		else if(id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText)) {
			if(sender == noteSplashesInputText) {
				_song.splashSkin = noteSplashesInputText.text;
				hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			}
			else if(sender == noteSkinInputText) {
				_song.arrowSkin = noteSkinInputText.text;
				hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			}
			else if(sender == gameOverCharacterInputText) {
				_song.gameOverChar = gameOverCharacterInputText.text;
				hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			}
			else if(sender == gameOverSoundInputText) {
				_song.gameOverSound = gameOverSoundInputText.text;
				hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			}
			else if(sender == gameOverLoopInputText) {
				_song.gameOverLoop = gameOverLoopInputText.text;
				hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			}
			else if(sender == gameOverEndInputText) {
				_song.gameOverEnd = gameOverEndInputText.text;
				hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
			}
			else if(curSelectedNote != null)
			{
				if(sender == value1InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][1] = value1InputText.text;
						hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
						updateGrid();
					}
				}
				else if(sender == value2InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][2] = value2InputText.text;
						hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
						updateGrid();
					}
				}
				else if(sender == strumTimeInputText) {
					var value:Float = Std.parseFloat(strumTimeInputText.text);
					if(Math.isNaN(value)) value = 0;
					curSelectedNote[0] = value;
					updateGrid();
				}
				else if(sender == value3InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][3] = value3InputText.text;
						hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
						updateGrid();
					}
				}
				else if(sender == value4InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][4] = value4InputText.text;
						hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
						updateGrid();
					}
				}
				else if(sender == value5InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][5] = value5InputText.text;
						hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
						updateGrid();
					}
				}
				else if(sender == value6InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][6] = value6InputText.text;
						hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
						updateGrid();
					}
				}
				else if(sender == value7InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][7] = value7InputText.text;
						hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
						updateGrid();
					}
				}
				else if(sender == value8InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][8] = value8InputText.text;
						hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
						updateGrid();
					}
				}
				else if(sender == value9InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][9] = value9InputText.text;
						hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
						updateGrid();
					}
				}
				else if(sender == value10InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][10] = value10InputText.text;
						hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
						updateGrid();
					}
				}
				else if(sender == value11InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][11] = value11InputText.text;
						hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
						updateGrid();
					}
				}
				else if(sender == value12InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][12] = value12InputText.text;
						hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
						updateGrid();
					}
				}
				else if(sender == value13InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][13] = value13InputText.text;
						hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
						updateGrid();
					}
				}
				else if(sender == value14InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][14] = value14InputText.text;
						hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
						updateGrid();
					}
				}
			}
		}
		else if (id == FlxUISlider.CHANGE_EVENT && (sender is FlxUISlider))
		{
			switch (sender)
			{
				case 'playbackSpeed':
					playbackSpeed = #if FLX_PITCH Std.int(sliderRate.value) #else 1.0 #end;
			}
		}

		// FlxG.log.add(id + " WEED " + sender + " WEED " + data + " WEED " + params);
	}

	var updatedSection:Bool = false;

	function sectionStartTime(add:Int = 0):Float
	{
		var daBPM:Float = _song.bpm;
		var daPos:Float = 0;
		for (i in 0...curSec + add)
		{
			if(_song.notes[i] != null)
			{
				if (_song.notes[i].changeBPM)
				{
					daBPM = _song.notes[i].bpm;
				}
				daPos += getSectionBeats(i) * (1000 * 60 / daBPM);
			}
		}
		return daPos;
	}

	var lastConductorPos:Float;
	var colorSine:Float = 0;
	override function update(elapsed:Float)
	{
		curStep = recalculateSteps();

		if(FlxG.sound.music.time < 0) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if(FlxG.sound.music.time > FlxG.sound.music.length) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		_song.songId = UI_songTitle.text;

		strumLineUpdateY();
		for (i in 0...8){
			strumLineNotes.members[i].y = strumLine.y;
		}

		FlxG.mouse.visible = !songStarted;//cause reasons. trust me
		camPos.y = strumLine.y;
		if(!disableAutoScrolling.checked) {
			if (Math.ceil(strumLine.y) >= gridBG.height)
			{
				if (_song.notes[curSec + 1] == null)
				{
					addSection();
				}

				changeSection(curSec + 1, false);
			} else if(strumLine.y < -10) {
				changeSection(curSec - 1, false);
			}
		}
		FlxG.watch.addQuick('daBeat', curBeat);
		FlxG.watch.addQuick('daStep', curStep);


		if (FlxG.mouse.x > gridBG.x
			&& FlxG.mouse.x < gridBG.x + gridBG.width
			&& FlxG.mouse.y > gridBG.y
			&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * getSectionBeats() * 4) * zoomList[curZoom])
		{
			dummyArrow.visible = true;
			dummyArrow.x = Math.floor(FlxG.mouse.x / GRID_SIZE) * GRID_SIZE;
			if (FlxG.keys.pressed.SHIFT)
				dummyArrow.y = FlxG.mouse.y;
			else
			{
				var gridmult = GRID_SIZE / (quantization / 16);
				dummyArrow.y = Math.floor(FlxG.mouse.y / gridmult) * gridmult;
			}
		} else {
			dummyArrow.visible = false;
		}

		if (FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.overlaps(curRenderedNotes))
			{
				curRenderedNotes.forEachAlive(function(note:Note)
				{
					if (FlxG.mouse.overlaps(note))
					{
						if (FlxG.keys.pressed.CONTROL)
						{
							selectNote(note);
						}
						else if (FlxG.keys.pressed.ALT)
						{
							selectNote(note);
							curSelectedNote[3] = curNoteTypes[currentType];
							updateGrid();
						}
						else
						{
							//Debug.logTrace('tryin to delete note...');
							deleteNote(note);
						}
					}
				});
			}
			else
			{
				if (FlxG.mouse.x > gridBG.x
					&& FlxG.mouse.x < gridBG.x + gridBG.width
					&& FlxG.mouse.y > gridBG.y
					&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * getSectionBeats() * 4) * zoomList[curZoom])
				{
					FlxG.log.add('added note');
					addNote();
				}
			}
		}

		var blockInput:Bool = false;
		for (inputText in blockPressWhileTypingOn) {
			if(inputText.hasFocus) {
				ClientPrefs.toggleVolumeKeys(false);
				blockInput = true;
				break;
			}
		}

		if(!blockInput) {
			for (stepper in blockPressWhileTypingOnStepper) {
				@:privateAccess
				var leText:FlxUIInputText = cast (stepper.text_field, FlxUIInputText);
				if(leText.hasFocus) {
					ClientPrefs.toggleVolumeKeys(false);
					blockInput = true;
					break;
				}
			}
		}

		if(!blockInput) {
			ClientPrefs.toggleVolumeKeys(true);
			for (dropDownMenu in blockPressWhileScrolling) {
				if(dropDownMenu.dropPanel.visible) {
					blockInput = true;
					break;
				}
			}
		}

		if (!blockInput)
		{
			if(FlxG.keys.justPressed.F1 || (helpBg.visible && FlxG.keys.justPressed.ESCAPE))
			{
				helpBg.visible = !helpBg.visible;
				helpTexts.visible = helpBg.visible;
			}
			else if (FlxG.keys.justPressed.ESCAPE)
			{
				if(FlxG.sound.music != null) FlxG.sound.music.pause();
				if(vocals != null)
				{
					vocals.pause();
					vocals.volume = 0;
				}
				if(opponentVocals != null)
				{
					opponentVocals.pause();
					opponentVocals.volume = 0;
				}

				autosaveSong();
				playtesting = true;
				playtestingTime = Conductor.songPosition;
				playtestingOnComplete = FlxG.sound.music.onComplete;
				openSubState(new states.editors.EditorPlaySubState(playbackSpeed));
			}
			if (FlxG.keys.justPressed.ENTER)
			{
				var exitFunc = function()
				{
					startSong();
				};
				if (hasUnsavedChanges)
				{
					persistentUpdate = false;
					var exitSubState = new ChartEditorExitSubstate(exitFunc);
					openSubState(exitSubState);
					exitSubState.camera = camHUD;
				}
				else exitFunc();
			}

			if(curSelectedNote != null && curSelectedNote[1] > -1) {
				if (FlxG.keys.justPressed.E)
				{
					changeNoteSustain(Conductor.stepCrochet);
				}
				if (FlxG.keys.justPressed.Q)
				{
					changeNoteSustain(-Conductor.stepCrochet);
				}
			}


			if (FlxG.keys.justPressed.BACKSPACE) {
				autosaveSong();

				PlayState.chartingMode = false;
				MusicBeatState.switchState(new states.editors.MasterEditorMenu());
				FlxG.sound.playMusic(Paths.music(ClientPrefs.data.SCEWatermark ? "SCE_freakyMenu" : "freakyMenu"));
				FlxG.mouse.visible = false;
				songStarted = true;
				return;
			}

			if(FlxG.keys.justPressed.Z && FlxG.keys.pressed.CONTROL) {
				undo();
			}

			if(FlxG.keys.justPressed.Z && curZoom > 0 && !FlxG.keys.pressed.CONTROL) {
				--curZoom;
				updateZoom();
			}
			if(FlxG.keys.justPressed.X && curZoom < zoomList.length-1) {
				curZoom++;
				updateZoom();
			}

			if (FlxG.keys.justPressed.TAB)
			{
				if (FlxG.keys.pressed.SHIFT)
				{
					UI_box.selected_tab -= 1;
					if (UI_box.selected_tab < 0)
						UI_box.selected_tab = 2;
				}
				else
				{
					UI_box.selected_tab += 1;
					if (UI_box.selected_tab >= 3)
						UI_box.selected_tab = 0;
				}
			}

			if (FlxG.keys.justPressed.SPACE)
			{
				if (vocals != null) vocals.play();
				if (opponentVocals != null) opponentVocals.play();
				pauseAndSetVocalsTime();
				if (!FlxG.sound.music.playing)
				{
					if (FlxG.sound.music != null) FlxG.sound.music.play();
					if (vocals != null) vocals.play();
					if (opponentVocals != null) opponentVocals.play();
				}
				else {
					if (FlxG.sound.music != null) FlxG.sound.music.pause();
				}
			}

			if (!FlxG.keys.pressed.ALT && FlxG.keys.justPressed.R)
			{
				if (FlxG.keys.pressed.SHIFT)
					resetSection(true);
				else
					resetSection();
			}

			if (FlxG.mouse.wheel != 0)
			{
				FlxG.sound.music.pause();
				if (!mouseQuant)
					FlxG.sound.music.time -= (FlxG.mouse.wheel * Conductor.stepCrochet*0.8);
				else
				{
					var time:Float = FlxG.sound.music.time;
					var beat:Float = curDecBeat;
					var snap:Float = quantization / 4;
					var increase:Float = 1 / snap;
					if (FlxG.mouse.wheel > 0)
					{
						var fuck:Float = CoolUtil.quantize(beat, snap) - increase;
						FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
					} else {
						var fuck:Float = CoolUtil.quantize(beat, snap) + increase;
						FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
					}
				}
				pauseAndSetVocalsTime();
			}

			//ARROW VORTEX SHIT NO DEADASS
			if (FlxG.keys.pressed.W || FlxG.keys.pressed.S)
			{
				FlxG.sound.music.pause();

				var holdingShift:Float = 1;
				if (FlxG.keys.pressed.CONTROL) holdingShift = 0.25;
				else if (FlxG.keys.pressed.SHIFT) holdingShift = 4;

				var daTime:Float = 700 * FlxG.elapsed * holdingShift;

				FlxG.sound.music.time += daTime * (FlxG.keys.pressed.W ? -1 : 1);

				pauseAndSetVocalsTime();
			}

			if(!vortex){
				if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN  )
				{
					FlxG.sound.music.pause();
					updateCurStep();
					var time:Float = FlxG.sound.music.time;
					var beat:Float = curDecBeat;
					var snap:Float = quantization / 4;
					var increase:Float = 1 / snap;
					if (FlxG.keys.pressed.UP)
					{
						var fuck:Float = CoolUtil.quantize(beat, snap) - increase; //(Math.floor((beat+snap) / snap) * snap);
						FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
					}else{
						var fuck:Float = CoolUtil.quantize(beat, snap) + increase; //(Math.floor((beat+snap) / snap) * snap);
						FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
					}
				}
			}

			var style = currentType;

			if (FlxG.keys.pressed.SHIFT){
				style = 3;
			}

			var conductorTime = Conductor.songPosition; //+ sectionStartTime();Conductor.songPosition / Conductor.stepCrochet;

			//AWW YOU MADE IT SEXY <3333 THX SHADMAR

			if(!blockInput){
				if(FlxG.keys.justPressed.RIGHT){
					curQuant++;
					if(curQuant>quantizations.length-1)
						curQuant = 0;

					quantization = quantizations[curQuant];
				}

				if(FlxG.keys.justPressed.LEFT){
					curQuant--;
					if(curQuant<0)
						curQuant = quantizations.length-1;

					quantization = quantizations[curQuant];
				}
				quant.animation.play('q', true, false, curQuant);
			}
			if(vortex && !blockInput){
				var controlArray:Array<Bool> = [FlxG.keys.justPressed.ONE, FlxG.keys.justPressed.TWO, FlxG.keys.justPressed.THREE, FlxG.keys.justPressed.FOUR,
											   FlxG.keys.justPressed.FIVE, FlxG.keys.justPressed.SIX, FlxG.keys.justPressed.SEVEN, FlxG.keys.justPressed.EIGHT];

				if(controlArray.contains(true))
				{
					for (i in 0...controlArray.length)
					{
						if(controlArray[i])
							doANoteThing(conductorTime, i, style);
					}
				}

				var feces:Float;
				if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN  )
				{
					FlxG.sound.music.pause();


					updateCurStep();
					//FlxG.sound.music.time = (Math.round(curStep/quants[curQuant])*quants[curQuant]) * Conductor.stepCrochet;

						//(Math.floor((curStep+quants[curQuant]*1.5/(quants[curQuant]/2))/quants[curQuant])*quants[curQuant]) * Conductor.stepCrochet;//snap into quantization
					var time:Float = FlxG.sound.music.time;
					var beat:Float = curDecBeat;
					var snap:Float = quantization / 4;
					var increase:Float = 1 / snap;
					if (FlxG.keys.pressed.UP)
					{
						var fuck:Float = CoolUtil.quantize(beat, snap) - increase;
						feces = Conductor.beatToSeconds(fuck);
					}else{
						var fuck:Float = CoolUtil.quantize(beat, snap) + increase; //(Math.floor((beat+snap) / snap) * snap);
						feces = Conductor.beatToSeconds(fuck);
					}
					FlxTween.tween(FlxG.sound.music, {time:feces}, 0.1, {ease:FlxEase.circOut});
					pauseAndSetVocalsTime();

					var dastrum = 0;

					if (curSelectedNote != null){
						dastrum = curSelectedNote[0];
					}

					var secStart:Float = sectionStartTime();
					var datime = (feces - secStart) - (dastrum - secStart); //idk math find out why it doesn't work on any other section other than 0
					if (curSelectedNote != null)
					{
						var controlArray:Array<Bool> = [FlxG.keys.pressed.ONE, FlxG.keys.pressed.TWO, FlxG.keys.pressed.THREE, FlxG.keys.pressed.FOUR,
													   FlxG.keys.pressed.FIVE, FlxG.keys.pressed.SIX, FlxG.keys.pressed.SEVEN, FlxG.keys.pressed.EIGHT];

						if(controlArray.contains(true))
						{

							for (i in 0...controlArray.length)
							{
								if(controlArray[i])
									if(curSelectedNote[1] == i) curSelectedNote[2] += datime - curSelectedNote[2] - Conductor.stepCrochet;
							}
							updateGrid();
							updateNoteUI();
						}
					}
				}
			}
			var shiftThing:Int = 1;
			if (FlxG.keys.pressed.SHIFT)
				shiftThing = 4;

			if (FlxG.keys.justPressed.H)
				changeSection(0);

			if (FlxG.keys.justPressed.D)
				changeSection(curSec + shiftThing);
			if (FlxG.keys.justPressed.A) {
				if(curSec <= 0) {
					changeSection(_song.notes.length-1);
				} else {
					changeSection(curSec - shiftThing);
				}
			}
		} else if (FlxG.keys.justPressed.ENTER) {
			for (i in 0...blockPressWhileTypingOn.length) {
				if(blockPressWhileTypingOn[i].hasFocus) {
					blockPressWhileTypingOn[i].hasFocus = false;
				}
			}
		}

		strumLineNotes.visible = quant.visible = vortex;

		if(FlxG.sound.music.time < 0) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if(FlxG.sound.music.time > FlxG.sound.music.length) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		strumLineUpdateY();
		camPos.y = strumLine.y;
		for (i in 0...strumLineNotes.members.length){
			strumLineNotes.members[i].y = strumLine.y;
			strumLineNotes.members[i].alpha = FlxG.sound.music.playing ? 1 : 0.35;
		}

		#if FLX_PITCH
		// PLAYBACK SPEED CONTROLS //
		var holdingShift = FlxG.keys.pressed.SHIFT;
		var holdingLB = FlxG.keys.pressed.LBRACKET;
		var holdingRB = FlxG.keys.pressed.RBRACKET;
		var pressedLB = FlxG.keys.justPressed.LBRACKET;
		var pressedRB = FlxG.keys.justPressed.RBRACKET;

		if (!holdingShift && pressedLB || holdingShift && holdingLB)
			playbackSpeed -= 0.01;
		if (!holdingShift && pressedRB || holdingShift && holdingRB)
			playbackSpeed += 0.01;
		if (FlxG.keys.pressed.ALT && (pressedLB || pressedRB || holdingLB || holdingRB))
			playbackSpeed = 1;
		//

		if (playbackSpeed <= 0.5)
			playbackSpeed = 0.5;
		if (playbackSpeed >= 3)
			playbackSpeed = 3;

		FlxG.sound.music.pitch = playbackSpeed;
		vocals.pitch = playbackSpeed;
		opponentVocals.pitch = playbackSpeed;
		#end

		var showTime:String = FlxStringUtil.formatTime(FlxMath.roundDecimal(Conductor.songPosition / 1000, 2), false) + ' / ' + FlxStringUtil.formatTime(FlxMath.roundDecimal(FlxG.sound.music.length / 1000, 2), false);
		var currentDifficulty:String = Difficulty.list[PlayState.storyDifficulty];
		var daSongPosition = FlxMath.roundDecimal(Conductor.songPosition / 1000, 2);
		var daLength = FlxMath.roundDecimal(FlxG.sound.music.length / 1000, 2);

		bpmTxt.text =
		_song.song + ' [' + currentDifficulty + ']' + 
		"\n"+ showTime +
		"\n"+
		"\n"+ 'Song Length: ' + Std.string(daSongPosition) + " / " + Std.string(daLength) +
		"\nSection: " + curSec +
		"\n\nBeat: " + Std.string(curDecBeat).substring(0,4) +
		"\n\nStep: " + curStep +
		"\n\nBeat Snap: " + quantization + (((quantization - 2) % 10 == 0 && quantization != 12) ? "nd" : "th") +
		"\n\nZoom: " + zoomFactorTxt;

		var playedSound:Array<Bool> = [false, false, false, false]; //Prevents ouchy GF sex sounds
		curRenderedNotes.forEachAlive(function(note:Note) {
			note.alpha = 1;
			if(curSelectedNote != null) {
				var noteDataToCheck:Int = note.noteData;
				if(noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += 4;

				if (curSelectedNote[0] == note.strumTime && ((curSelectedNote[2] == null && noteDataToCheck < 0) || (curSelectedNote[2] != null && curSelectedNote[1] == noteDataToCheck)))
				{
					colorSine += elapsed;
					var colorVal:Float = 0.7 + Math.sin(Math.PI * colorSine) * 0.3;
					note.color = FlxColor.fromRGBFloat(colorVal, colorVal, colorVal, 0.999); //Alpha can't be 100% or the color won't be updated for some reason, guess i will die
				}
			}

			if(note.strumTime <= Conductor.songPosition) {
				note.alpha = 0.4;
				if(note.strumTime > lastConductorPos && note.noteData > -1) {
					var data:Int = note.noteData % 4;
					var noteDataToCheck:Int = note.noteData;
					if(noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += 4;
						strumLineNotes.members[noteDataToCheck].playAnim('confirm', true);
						strumLineNotes.members[noteDataToCheck].resetAnim = ((note.sustainLength / 1000) + 0.15) / playbackSpeed;
					if(!playedSound[data]) {
						if(note.hitsoundChartEditor && ((playSoundBf.checked && note.mustPress) || (playSoundDad.checked && !note.mustPress)))
						{
							var soundToPlay = note.hitsound;
							if(_song.player1 == 'gf') //Easter egg
								soundToPlay = 'GF_' + Std.string(data + 1);

							FlxG.sound.play(Paths.sound(soundToPlay)).pan = note.noteData < 4 ? -0.3 : 0.3; //would be coolio
							playedSound[data] = true;
						}

						data = note.noteData;
						if(note.mustPress != _song.notes[curSec].mustHitSection)
						{
							data += 4;
						}
					}
				}
			}
		});

		if(metronome.checked && lastConductorPos != Conductor.songPosition) {
			var metroInterval:Float = 60 / metronomeStepper.value;
			var metroStep:Int = Math.floor(((Conductor.songPosition + metronomeOffsetStepper.value) / metroInterval) / 1000);
			var lastMetroStep:Int = Math.floor(((lastConductorPos + metronomeOffsetStepper.value) / metroInterval) / 1000);
			if(metroStep != lastMetroStep) {
				FlxG.sound.play(Paths.sound('Metronome_Tick'));
				//Debug.logTrace('Ticked');
			}
		}
		lastConductorPos = Conductor.songPosition;
		super.update(elapsed);
	}

	function pauseAndSetVocalsTime()
	{
		if(vocals != null)
		{
			vocals.pause();
			vocals.time = FlxG.sound.music.time;
		}

		if(opponentVocals != null)
		{
			opponentVocals.pause();
			opponentVocals.time = FlxG.sound.music.time;
		}
	}

	function startSong(){
		IndieDiamondTransSubState.placedZoom = 1.2;
		autosaveSong();
		songStarted = true;
		FlxG.mouse.visible = false;
		PlayState.SONG = _song;
		FlxG.sound.music.stop();
		if(vocals != null) vocals.stop();
		if(opponentVocals != null) opponentVocals.stop();

		//if(_song.stage == null) _song.stage = stageDropDown.selectedLabel;
		StageData.loadDirectory(_song);
		IndieDiamondTransSubState.divideZoom = true;
		LoadingState.loadAndSwitchState(new PlayState());
		songStarted = true;
	}

	function updateZoom() {
		var daZoom:Float = zoomList[curZoom];
		zoomFactorTxt = '1 / ' + daZoom;
		if(daZoom < 1) zoomFactorTxt = Math.round(1 / daZoom) + ' / 1';
		reloadGridLayer();
	}

	override function destroy()
	{
		Note.globalRgbShaders = [];
		backend.NoteTypesConfig.clearNoteTypesData();
		super.destroy();
	}

	var lastSecBeats:Float = 0;
	var lastSecBeatsNext:Float = 0;
	var columns:Int = 9;
	function reloadGridLayer() {
		gridLayer.clear();

		gridBG = FlxGridOverlay.create(1, 1, columns, Std.int(getSectionBeats() * 4 * zoomList[curZoom]));
		gridBG.antialiasing = false;
		gridBG.scale.set(GRID_SIZE, GRID_SIZE);
		gridBG.updateHitbox();

		#if desktop
		if(FlxG.save.data.chart_waveformInst || FlxG.save.data.chart_waveformVoices || FlxG.save.data.chart_waveformOppVoices) {
			updateWaveform();
		}
		#end

		var leHeight:Int = Std.int(gridBG.height);
		var foundNextSec:Bool = false;
		if(sectionStartTime(1) <= FlxG.sound.music.length)
		{
			nextGridBG = FlxGridOverlay.create(1, 1, columns, Std.int(getSectionBeats(curSec + 1) * 4 * zoomList[curZoom]));
			nextGridBG.antialiasing = false;
			nextGridBG.scale.set(GRID_SIZE, GRID_SIZE);
			nextGridBG.updateHitbox();
			leHeight = Std.int(gridBG.height + nextGridBG.height);
			foundNextSec = true;
		}
		else nextGridBG = new FlxSprite().makeGraphic(1, 1, FlxColor.TRANSPARENT);
		nextGridBG.y = gridBG.height;
		
		gridLayer.add(nextGridBG);
		gridLayer.add(gridBG);

		if(foundNextSec)
		{
			var gridBlack:FlxSprite = new FlxSprite(0, gridBG.height).makeGraphic(1, 1, FlxColor.BLACK);
			gridBlack.setGraphicSize(Std.int(GRID_SIZE * 9), Std.int(nextGridBG.height));
			gridBlack.updateHitbox();
			gridBlack.antialiasing = false;
			gridBlack.alpha = 0.4;
			gridLayer.add(gridBlack);
		}

		var gridBlackLine:FlxSprite = new FlxSprite(gridBG.x + gridBG.width - (GRID_SIZE * 4)).makeGraphic(1, 1, FlxColor.BLACK);
		gridBlackLine.setGraphicSize(2, leHeight);
		gridBlackLine.updateHitbox();
		gridBlackLine.antialiasing = false;
		gridLayer.add(gridBlackLine);

		for (i in 1...Std.int(getSectionBeats())) {
			var beatsep:FlxSprite = new FlxSprite(gridBG.x, (GRID_SIZE * (4 * zoomList[curZoom])) * i).makeGraphic(1, 1, 0x44FF0000);
			beatsep.scale.x = gridBG.width;
			beatsep.updateHitbox();
			if(vortex) gridLayer.add(beatsep);
		}

		var gridBlackLine:FlxSprite = new FlxSprite(gridBG.x + GRID_SIZE).makeGraphic(1, 1, FlxColor.BLACK);
		gridBlackLine.setGraphicSize(2, leHeight);
		gridBlackLine.updateHitbox();
		gridBlackLine.antialiasing = false;
		gridLayer.add(gridBlackLine);

		if (strumLine != null)
		{
			remove(strumLine);
			strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(GRID_SIZE * 9), 4);
			add(strumLine);
		}

		if (strumLineNotes != null)
		{
			strumLineNotes.clear();
			for (i in 0...8){
				var note:StrumArrow = new StrumArrow(GRID_SIZE * (i+1), strumLine.y, i % 4, 0, _song.arrowSkin);
				note.setGraphicSize(GRID_SIZE, GRID_SIZE);
				note.updateHitbox();
				note.playAnim('static', true);
				strumLineNotes.add(note);
				note.scrollFactor.set(1, 1);
			}
		}

		updateGrid();

		lastSecBeats = getSectionBeats();
		if(sectionStartTime(1) > FlxG.sound.music.length) lastSecBeatsNext = 0;
		else getSectionBeats(curSec + 1);
	}

	function strumLineUpdateY()
	{
		strumLine.y = getYfromStrum((Conductor.songPosition - sectionStartTime()) / zoomList[curZoom] % (Conductor.stepCrochet * 16)) / (getSectionBeats() / 4);
	}

	var waveformPrinted:Bool = true;
	var wavData:Array<Array<Array<Float>>> = [[[0], [0]], [[0], [0]]];

	var lastWaveformHeight:Int = 0;
	function updateWaveform() {
		#if desktop
		if(waveformPrinted) {
			var width:Int = Std.int(GRID_SIZE * 8);
			var height:Int = Std.int(gridBG.height);
			if(lastWaveformHeight != height && waveformSprite.pixels != null)
			{
				waveformSprite.pixels.dispose();
				waveformSprite.pixels.disposeImage();
				waveformSprite.makeGraphic(width, height, 0x00FFFFFF);
				lastWaveformHeight = height;
			}
			waveformSprite.pixels.fillRect(new Rectangle(0, 0, width, height), 0x00FFFFFF);
		}
		waveformPrinted = false;

		if(!FlxG.save.data.chart_waveformInst && !FlxG.save.data.chart_waveformVoices && !FlxG.save.data.chart_waveformOppVoices) {
			Debug.logInfo('Epic fail on the waveform lol');
			return;
		}

		wavData[0][0] = [];
		wavData[0][1] = [];
		wavData[1][0] = [];
		wavData[1][1] = [];

		var steps:Int = Math.round(getSectionBeats() * 4);
		var st:Float = sectionStartTime();
		var et:Float = st + (Conductor.stepCrochet * steps);

		var sound:FlxSound = FlxG.sound.music;
		if(FlxG.save.data.chart_waveformVoices)
			sound = vocals;
		else if(FlxG.save.data.chart_waveformOppVoices && opponentVocals != null)
			sound = opponentVocals;

		if (sound != null && sound._sound != null && sound._sound.__buffer != null) {
			var bytes:Bytes = sound._sound.__buffer.data.toBytes();
			wavData = waveformData(
				sound._sound.__buffer,
				bytes,
				st,
				et,
				1,
				wavData,
				Std.int(gridBG.height)
			);
		}

		// Draws
		var gSize:Int = Std.int(GRID_SIZE * 8);
		var hSize:Int = Std.int(gSize / 2);

		var size:Float = 1;

		var leftLength:Int = (wavData[0][0].length > wavData[0][1].length ? wavData[0][0].length : wavData[0][1].length);
		var rightLength:Int = (wavData[1][0].length > wavData[1][1].length ? wavData[1][0].length : wavData[1][1].length);

		var length:Int = leftLength > rightLength ? leftLength : rightLength;

		for (index in 0...length)
		{
			var lmin:Float = FlxMath.bound(((index < wavData[0][0].length && index >= 0) ? wavData[0][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			var lmax:Float = FlxMath.bound(((index < wavData[0][1].length && index >= 0) ? wavData[0][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			var rmin:Float = FlxMath.bound(((index < wavData[1][0].length && index >= 0) ? wavData[1][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			var rmax:Float = FlxMath.bound(((index < wavData[1][1].length && index >= 0) ? wavData[1][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			waveformSprite.pixels.fillRect(new Rectangle(hSize - (lmin + rmin), index * size, (lmin + rmin) + (lmax + rmax), size), FlxColor.BLUE);
		}

		waveformPrinted = true;
		#end
	}

	function waveformData(buffer:AudioBuffer, bytes:Bytes, time:Float, endTime:Float, multiply:Float = 1, ?array:Array<Array<Array<Float>>>, ?steps:Float):Array<Array<Array<Float>>>
	{
		#if (lime_cffi && !macro)
		if (buffer == null || buffer.data == null) return [[[0], [0]], [[0], [0]]];

		var khz:Float = (buffer.sampleRate / 1000);
		var channels:Int = buffer.channels;

		var index:Int = Std.int(time * khz);

		var samples:Float = ((endTime - time) * khz);

		if (steps == null) steps = 1280;

		var samplesPerRow:Float = samples / steps;
		var samplesPerRowI:Int = Std.int(samplesPerRow);

		var gotIndex:Int = 0;

		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		var rows:Float = 0;

		var simpleSample:Bool = true;//samples > 17200;
		var v1:Bool = false;

		if (array == null) array = [[[0], [0]], [[0], [0]]];

		while (index < (bytes.length - 1)) {
			if (index >= 0) {
				var byte:Int = bytes.getUInt16(index * channels * 2);

				if (byte > 65535 / 2) byte -= 65535;

				var sample:Float = (byte / 65535);

				if (sample > 0)
					if (sample > lmax) lmax = sample;
				else if (sample < 0)
					if (sample < lmin) lmin = sample;

				if (channels >= 2) 
				{
					byte = bytes.getUInt16((index * channels * 2) + 2);

					if (byte > 65535 / 2) byte -= 65535;

					sample = (byte / 65535);

					if (sample > 0) {
						if (sample > rmax) rmax = sample;
					} else if (sample < 0) {
						if (sample < rmin) rmin = sample;
					}
				}
			}

			v1 = samplesPerRowI > 0 ? (index % samplesPerRowI == 0) : false;
			while (simpleSample ? v1 : rows >= samplesPerRow) {
				v1 = false;
				rows -= samplesPerRow;

				gotIndex++;

				var lRMin:Float = Math.abs(lmin) * multiply;
				var lRMax:Float = lmax * multiply;

				var rRMin:Float = Math.abs(rmin) * multiply;
				var rRMax:Float = rmax * multiply;

				if (gotIndex > array[0][0].length) array[0][0].push(lRMin);
					else array[0][0][gotIndex - 1] = array[0][0][gotIndex - 1] + lRMin;

				if (gotIndex > array[0][1].length) array[0][1].push(lRMax);
					else array[0][1][gotIndex - 1] = array[0][1][gotIndex - 1] + lRMax;

				if (channels >= 2) 
				{
					if (gotIndex > array[1][0].length) array[1][0].push(rRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + rRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(rRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + rRMax;
				}
				else 
				{
					if (gotIndex > array[1][0].length) array[1][0].push(lRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + lRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(lRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + lRMax;
				}

				lmin = 0;
				lmax = 0;

				rmin = 0;
				rmax = 0;
			}

			index++;
			rows++;
			if(gotIndex > steps) break;
		}

		return array;
		#else
		return [[[0], [0]], [[0], [0]]];
		#end
	}

	function changeNoteSustain(value:Float):Void
	{
		if (curSelectedNote != null)
		{
			if (curSelectedNote[2] != null)
			{
				curSelectedNote[2] += Math.ceil(value);
				curSelectedNote[2] = Math.max(curSelectedNote[2], 0);
			}
		}

		hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!

		updateNoteUI();
		updateGrid();
	}

	function recalculateSteps(add:Float = 0):Int
	{
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: 0
		}
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (FlxG.sound.music.time > Conductor.bpmChangeMap[i].songTime)
				lastChange = Conductor.bpmChangeMap[i];
		}

		curStep = lastChange.stepTime + Math.floor((FlxG.sound.music.time - lastChange.songTime + add) / Conductor.stepCrochet);
		updateBeat();

		return curStep;
	}

	function resetSection(songBeginning:Bool = false):Void
	{
		updateGrid();

		FlxG.sound.music.pause();
		// Basically old shit from changeSection???
		FlxG.sound.music.time = sectionStartTime();

		if (songBeginning)
		{
			FlxG.sound.music.time = 0;
			curSec = 0;
		}

		pauseAndSetVocalsTime();
		updateCurStep();

		updateGrid();
		updateSectionUI();
		updateWaveform();
	}

	function changeSection(sec:Int = 0, ?updateMusic:Bool = true):Void
	{
		var waveformChanged:Bool = false;
		if (_song.notes[sec] != null)
		{
			curSec = sec;
			if (updateMusic)
			{
				FlxG.sound.music.pause();

				FlxG.sound.music.time = sectionStartTime();
				pauseAndSetVocalsTime();
				updateCurStep();
			}

			var blah1:Float = getSectionBeats();
			var blah2:Float = getSectionBeats(curSec + 1);
			if(sectionStartTime(1) > FlxG.sound.music.length) blah2 = 0;
	
			if(blah1 != lastSecBeats || blah2 != lastSecBeatsNext)
			{
				reloadGridLayer();
				waveformChanged = true;
			}
			else
			{
				updateGrid();
			}
			updateSectionUI();
		}
		else
		{
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		if(!waveformChanged) updateWaveform();
	}

	function updateSectionUI():Void
	{
		var sec = _song.notes[curSec];

		stepperBeats.value = getSectionBeats();
		check_mustHitSection.checked = sec.mustHitSection;
		check_player4Section.checked = sec.player4Section;
		check_gfSection.checked = sec.gfSection;
		check_altAnim.checked = sec.altAnim;
		check_playerAltAnim.checked = sec.playerAltAnim;
		check_CPUAltAnim.checked = sec.CPUAltAnim;
		stepperDType.value = sec.dType;
		check_changeBPM.checked = sec.changeBPM;
		stepperSectionBPM.value = sec.bpm;

		updateHeads();
	}

	var characterData:Dynamic = {
		iconP1: null,
		iconP2: null,
		iconGF: null,
		vocalsP1: null,
		vocalsP2: null,
		vocalsP3: null
	};

	function updateJsonData():Void
	{
		for (i in 1...3)
		{
			var data:CharacterFile = loadCharacterFile(Reflect.field(_song, 'player$i'));
			var extraData:CharacterFile = loadCharacterFile(Reflect.field(_song, 'gfVersion'));
			Reflect.setField(characterData, 'iconP$i', !characterFailed ? data.healthicon : 'face');
			Reflect.setField(characterData, 'iconGF', !characterFailed ? extraData.healthicon : 'face');
			Reflect.setField(characterData, 'vocalsP$i', data.vocals_file != null ? data.vocals_file : '');
		}
		var p1:CharacterFile = loadCharacterFile(_song.player1);
		var p2:CharacterFile = loadCharacterFile(_song.player2);
		var gf:CharacterFile = loadCharacterFile(_song.gfVersion);
	}

	function updateHeads():Void
	{
		if (_song.notes[curSec].mustHitSection)
		{
			leftIcon.changeIcon(characterData.iconP1);
			rightIcon.changeIcon(characterData.iconP2);
			if (_song.notes[curSec].gfSection) leftIcon.changeIcon(characterData.iconGF); //leftIcon.changeIcon(healthIconGF);
		}
		else
		{
			leftIcon.changeIcon(characterData.iconP2);
			rightIcon.changeIcon(characterData.iconP1);
			if (_song.notes[curSec].gfSection) leftIcon.changeIcon(characterData.iconGF); //leftIcon.changeIcon(healthIconGF);
		}
	}

	var characterFailed:Bool = false;
	function loadCharacterFile(char:String):CharacterFile {
		characterFailed = false;
		var characterPath:String = 'data/characters/' + char + '.json';
		#if MODS_ALLOWED
		var path:String = Paths.modFolders(characterPath);
		if (!FileSystem.exists(path)) {
			path = Paths.getSharedPath(characterPath);
		}

		if (!FileSystem.exists(path))
		#else
		var path:String = Paths.getSharedPath(characterPath);
		if (!OpenFlAssets.exists(path))
		#end
		{
			path = Paths.getSharedPath('data/characters/' + Character.DEFAULT_CHARACTER + '.json'); //If a character couldn't be found, change him to BF just to prevent a crash
			characterFailed = true;
		}

		#if MODS_ALLOWED
		var rawJson = File.getContent(path);
		#else
		var rawJson = OpenFlAssets.getText(path);
		#end

		return cast Json.parse(rawJson);
	}

	function updateNoteUI():Void
	{
		if (curSelectedNote != null) {
			if(curSelectedNote[2] != null) {
				stepperSusLength.value = curSelectedNote[2];
				if(curSelectedNote[3] != null) {
					currentType = curNoteTypes.indexOf(curSelectedNote[3]);
					if(currentType <= 0) {
						noteTypeDropDown.selectedLabel = '';
					} else {
						noteTypeDropDown.selectedLabel = currentType + '. ' + curSelectedNote[3];
					}
				}
			} else {
				eventDropDown.selectedLabel = curSelectedNote[1][curEventSelected][0];
				var selected:Int = Std.parseInt(eventDropDown.selectedId);
				if(selected > 0 && selected < eventStuff.length) {
					descText.text = eventStuff[selected][1];
				}
				value1InputText.text = curSelectedNote[1][curEventSelected][1];
				value2InputText.text = curSelectedNote[1][curEventSelected][2];
				value3InputText.text = curSelectedNote[1][curEventSelected][3];
				value4InputText.text = curSelectedNote[1][curEventSelected][4];
				value5InputText.text = curSelectedNote[1][curEventSelected][5];
				value6InputText.text = curSelectedNote[1][curEventSelected][6];
				value7InputText.text = curSelectedNote[1][curEventSelected][7];
				value8InputText.text = curSelectedNote[1][curEventSelected][8];
				value9InputText.text = curSelectedNote[1][curEventSelected][9];
				value10InputText.text = curSelectedNote[1][curEventSelected][10];
				value11InputText.text = curSelectedNote[1][curEventSelected][11];
				value12InputText.text = curSelectedNote[1][curEventSelected][12];
				value13InputText.text = curSelectedNote[1][curEventSelected][13];
				value14InputText.text = curSelectedNote[1][curEventSelected][14];
			}
			strumTimeInputText.text = '' + curSelectedNote[0];
		}
	}

	function updateGrid():Void
	{
		curRenderedNotes.forEachAlive(function(spr:Note) spr.destroy());
		curRenderedNotes.clear();
		curRenderedSustains.forEachAlive(function(spr:FlxSprite) spr.destroy());
		curRenderedSustains.clear();
		curRenderedNoteType.forEachAlive(function(spr:FlxText) spr.destroy());
		curRenderedNoteType.clear();
		nextRenderedNotes.forEachAlive(function(spr:Note) spr.destroy());
		nextRenderedNotes.clear();
		nextRenderedSustains.forEachAlive(function(spr:FlxSprite) spr.destroy());
		nextRenderedSustains.clear();

		if (_song.notes[curSec].changeBPM && _song.notes[curSec].bpm > 0)
		{
			Conductor.bpm = _song.notes[curSec].bpm;
			//Debug.logTrace('BPM of this section:');
		}
		else
		{
			// get last bpm
			var daBPM:Float = _song.bpm;
			for (i in 0...curSec)
				if (_song.notes[i].changeBPM)
					daBPM = _song.notes[i].bpm;
			Conductor.bpm = daBPM;
		}

		// CURRENT SECTION
		var beats:Float = getSectionBeats();
		for (i in _song.notes[curSec].sectionNotes)
		{
			var note:Note = setupNoteData(i, false);
			curRenderedNotes.add(note);
			if (note.sustainLength > 0)
			{
				curRenderedSustains.add(setupSusNote(note, beats));
			}

			if(i[3] != null && note.noteType != null && note.noteType.length > 0) {
				var typeInt:Int = curNoteTypes.indexOf(i[3]);
				var theType:String = '' + typeInt;
				if(typeInt < 0) theType = '?';

				var daText:AttachedFlxText = new AttachedFlxText(0, 0, 100, theType, 24);
				daText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
				daText.xAdd = -32;
				daText.yAdd = 6;
				daText.borderSize = 1;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;
			}
			note.mustPress = _song.notes[curSec].mustHitSection;
			if(i[1] > 3) note.mustPress = !note.mustPress;
		}

		// CURRENT EVENTS
		var startThing:Float = sectionStartTime();
		var endThing:Float = sectionStartTime(1);
		for (i in _song.events)
		{
			if(endThing > i[0] && i[0] >= startThing)
			{
				var note:Note = setupNoteData(i, false);
				curRenderedNotes.add(note);

				var theDumbText:String = '';
				for (i in 1...14){
					theDumbText += '\nValue 1: ' + i;
				}
				var text:String = 'Event: ' + note.eventName + ' (' + Math.floor(note.strumTime) + ' ms)' + theDumbText + ' Events:\n' + note.eventName;

				var daText:AttachedFlxText = new AttachedFlxText(0, 0, 410, text, 12);
				daText.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
				daText.xAdd = -410;
				daText.borderSize = 1;
				if(note.eventLength > 1) daText.yAdd += 8;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;
				//Debug.logTrace('test: ' + i[0], 'startThing: ' + startThing, 'endThing: ' + endThing);
			}
		}

		// NEXT SECTION
		var beats:Float = getSectionBeats(1);
		if(curSec < _song.notes.length-1) {
			for (i in _song.notes[curSec+1].sectionNotes)
			{
				var note:Note = setupNoteData(i, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
				if (note.sustainLength > 0)
				{
					nextRenderedSustains.add(setupSusNote(note, beats));
				}
			}
		}

		// NEXT EVENTS
		var startThing:Float = sectionStartTime(1);
		var endThing:Float = sectionStartTime(2);
		for (i in _song.events)
		{
			if(endThing > i[0] && i[0] >= startThing)
			{
				var note:Note = setupNoteData(i, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
			}
		}
	}

	function setupNoteData(i:Array<Dynamic>, isNextSection:Bool):Note
	{
		var daNoteInfo = i[1];
		var daStrumTime = i[0];
		var daSus:Dynamic = i[2];

		var note:Note = new Note(daStrumTime, daNoteInfo % 4, null, null, _song.arrowSkin, true);
		if(daSus != null) { //Common note
			if(!Std.isOfType(i[3], String)) //Convert old note type to new note type format
			{
				i[3] = curNoteTypes[i[3]];
			}
			if(i.length > 3 && (i[3] == null || i[3].length < 1))
			{
				i.remove(i[3]);
			}
			note.sustainLength = daSus;
			note.noteType = i[3];
		} else { //Event note
			note.loadGraphic(Paths.image('eventArrow'));
			note.rgbShader.enabled = false;
			note.eventName = getEventName(i[1]);
			note.eventLength = i[1].length;
			if(i[1].length < 2)
			{
				for (j in 1...14){
					note.eventVals.push(i[1][0][j]);
				}
			}
			note.noteData = -1;
			daNoteInfo = -1;
		}

		note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		note.updateHitbox();
		note.x = Math.floor(daNoteInfo * GRID_SIZE) + GRID_SIZE;
		if(isNextSection && _song.notes[curSec].mustHitSection != _song.notes[curSec+1].mustHitSection) {
			if(daNoteInfo > 3) {
				note.x -= GRID_SIZE * 4;
			} else if(daSus != null) {
				note.x += GRID_SIZE * 4;
			}
		}

		var beats:Float = getSectionBeats(isNextSection ? 1 : 0);
		note.y = getYfromStrumArrows(daStrumTime - sectionStartTime(), beats);
		//if(isNextSection) note.y += gridBG.height;
		if(note.y < -150) note.y = -150;
		return note;
	}

	function getEventName(names:Array<Dynamic>):String
	{
		var retStr:String = '';
		var addedOne:Bool = false;
		for (i in 0...names.length)
		{
			if(addedOne) retStr += ', ';
			retStr += names[i][0];
			addedOne = true;
		}
		return retStr;
	}

	var noteColors:Array<FlxColor> = [];

	function setupSusNote(note:Note, beats:Float):FlxSprite {
		var height:Int = Math.floor(FlxMath.remapToRange(note.sustainLength, 0, Conductor.stepCrochet * 16, 0, GRID_SIZE * 16 * zoomList[curZoom]) + (GRID_SIZE * zoomList[curZoom]) - GRID_SIZE / 2);
		var minHeight:Int = Std.int((GRID_SIZE * zoomList[curZoom] / 2) + GRID_SIZE / 2);
		if(height < minHeight) height = minHeight;
		if(height < 1) height = 1; //Prevents error of invalid height

		var isPixel = (note != null && (note.noteSkin.contains('pixel') || note.texture.contains('pixel') || note.containsPixelTexture));

		noteColors = (!isPixel ? ClientPrefs.data.arrowRGB[note.noteData % 4]
			: ClientPrefs.data.arrowRGBPixel[note.noteData % 4]);

		var spr:FlxSprite = new FlxSprite(note.x + (GRID_SIZE * 0.5) - 4, note.y + GRID_SIZE / 2).makeGraphic(8, height);
		spr.color = _song.disableNoteRGB ? FlxColor.RED : noteColors[0];
		spr.alpha = 0.6;
		spr.antialiasing = false;
		spr.active = false;
		return spr;
	}

	private function addSection(sectionBeats:Float = 4):Void
	{
		var sec:SwagSection = {
			sectionBeats: sectionBeats,
			bpm: _song.bpm,
			changeBPM: false,
			mustHitSection: true,
			player4Section: false,
			gfSection: false,
			sectionNotes: [],
			altAnim: false,
			CPUAltAnim: false,
			playerAltAnim: false,
			dType: 0
		};

		_song.notes.push(sec);
	}

	function selectNote(note:Note):Void
	{
		var noteDataToCheck:Int = note.noteData;

		if(noteDataToCheck > -1)
		{
			if(note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += 4;
			for (i in _song.notes[curSec].sectionNotes)
			{
				if (i != curSelectedNote && i.length > 2 && i[0] == note.strumTime && i[1] == noteDataToCheck)
				{
					curSelectedNote = i;
					break;
				}
			}
		}
		else
		{
			for (i in _song.events)
			{
				if(i != curSelectedNote && i[0] == note.strumTime)
				{
					curSelectedNote = i;
					curEventSelected = Std.int(curSelectedNote[1].length) - 1;
					break;
				}
			}
		}
		changeEventSelected();

		updateGrid();
		updateNoteUI();
	}

	function deleteNote(note:Note):Void
	{
		var noteDataToCheck:Int = note.noteData;
		if(noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += 4;

		if(note.noteData > -1) //Normal Notes
		{
			for (i in _song.notes[curSec].sectionNotes)
			{
				if (i[0] == note.strumTime && i[1] == noteDataToCheck)
				{
					if(i == curSelectedNote) curSelectedNote = null;
					//FlxG.log.add('FOUND EVIL NOTE');
					_song.notes[curSec].sectionNotes.remove(i);
					break;
				}
			}
		}
		else //Events
		{
			for (i in _song.events)
			{
				if(i[0] == note.strumTime)
				{
					if(i == curSelectedNote)
					{
						curSelectedNote = null;
						changeEventSelected();
					}
					//FlxG.log.add('FOUND EVIL EVENT');
					_song.events.remove(i);
					break;
				}
			}
		}

		updateGrid();

		hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
	}

	public function doANoteThing(cs, d, style){
		var delnote = false;
		if(strumLineNotes.members[d].overlaps(curRenderedNotes))
		{
			curRenderedNotes.forEachAlive(function(note:Note)
			{
				if (note.overlapsPoint(new FlxPoint(strumLineNotes.members[d].x + 1,strumLine.y+1)) && note.noteData == d%4)
				{
						//Debug.logTrace('tryin to delete note...');
						if(!delnote) deleteNote(note);
						delnote = true;
				}
			});
		}

		if (!delnote){
			addNote(cs, d, style);
		}
	}
	function clearSong():Void
	{
		for (daSection in 0..._song.notes.length)
		{
			_song.notes[daSection].sectionNotes = [];
		}

		hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!

		updateGrid();
	}

	private function addNote(strum:Null<Float> = null, data:Null<Int> = null, type:Null<Int> = null):Void
	{
		curUndoIndex++;
		var newsong = _song.notes;
		undos.push(newsong);
		var noteStrum = getStrumTime(dummyArrow.y * (getSectionBeats() / 4), false) + sectionStartTime();
		var noteData = Math.floor((FlxG.mouse.x - GRID_SIZE) / GRID_SIZE);
		var noteSus = 0;
		var daAlt = false;
		var daType = currentType;

		if (strum != null) noteStrum = strum;
		if (data != null) noteData = data;
		if (type != null) daType = type;

		if(noteData > -1)
		{
			_song.notes[curSec].sectionNotes.push([noteStrum, noteData, noteSus, curNoteTypes[daType]]);
			curSelectedNote = _song.notes[curSec].sectionNotes[_song.notes[curSec].sectionNotes.length - 1];
		}
		else
		{
			var event = eventStuff[Std.parseInt(eventDropDown.selectedId)][0];
			var text1 = value1InputText.text;
			var text2 = value2InputText.text;
			var text3 = value3InputText.text;
			var text4 = value4InputText.text;
			var text5 = value5InputText.text;
			var text6 = value6InputText.text;
			var text7 = value7InputText.text;
			var text8 = value8InputText.text;
			var text9 = value9InputText.text;
			var text10 = value10InputText.text;
			var text11 = value11InputText.text;
			var text12 = value12InputText.text;
			var text13 = value13InputText.text;
			var text14 = value14InputText.text;
			_song.events.push([noteStrum, [[event, text1, text2, text3, text4, text5, text6, text7, text8, text9, text10, text11, text12, text13, text14]]]);
			curSelectedNote = _song.events[_song.events.length - 1];
			curEventSelected = 0;
		}
		changeEventSelected();

		if (FlxG.keys.pressed.CONTROL && noteData > -1)
		{
			_song.notes[curSec].sectionNotes.push([noteStrum, (noteData + 4) % 8, noteSus, curNoteTypes[daType]]);
		}

		//Debug.logTrace(noteData + ', ' + noteStrum + ', ' + curSec);
		strumTimeInputText.text = '' + curSelectedNote[0];

		updateGrid();
		updateNoteUI();

		hasUnsavedChanges = true; //Copies modcharteditor's way of telling if something changed!
	}

	// will figure this out l8r
	function redo()
	{
		_song = redos[curRedoIndex];
	}

	function undo()
	{
		redos.push(_song);
		undos.pop();
		_song.notes = undos[undos.length - 1];
		Debug.logTrace(_song.notes);
		updateGrid();
	}

	function getStrumTime(yPos:Float, doZoomCalc:Bool = true):Float
	{
		var leZoom:Float = zoomList[curZoom];
		if(!doZoomCalc) leZoom = 1;
		return FlxMath.remapToRange(yPos, gridBG.y, gridBG.y + gridBG.height * leZoom, 0, 16 * Conductor.stepCrochet);
	}

	function getYfromStrum(strumTime:Float, doZoomCalc:Bool = true):Float
	{
		var leZoom:Float = zoomList[curZoom];
		if(!doZoomCalc) leZoom = 1;
		return FlxMath.remapToRange(strumTime, 0, 16 * Conductor.stepCrochet, gridBG.y, gridBG.y + gridBG.height * leZoom);
	}
	
	function getYfromStrumArrows(strumTime:Float, beats:Float):Float
	{
		var value:Float = strumTime / (beats * 4 * Conductor.stepCrochet);
		return GRID_SIZE * beats * 4 * zoomList[curZoom] * value + gridBG.y;
	}

	function getNotes():Array<Dynamic>
	{
		var noteData:Array<Dynamic> = [];

		for (i in _song.notes)
		{
			noteData.push(i.sectionNotes);
		}

		return noteData;
	}

	var missingText:FlxText;
	var missingTextTimer:FlxTimer;
	function loadJson(song:String):Void
	{
		//shitty null fix, i fucking hate it when this happens
		//make it look sexier if possible
		try {
			if (Difficulty.getString() != Difficulty.getDefault()) {
				if(Difficulty.getString() == null){
					PlayState.SONG = Song.loadFromJson(song.toLowerCase(), song.toLowerCase());
				}else{
					PlayState.SONG = Song.loadFromJson(song.toLowerCase() + "-" + Difficulty.getString(), song.toLowerCase());
				}
			}
			else PlayState.SONG = Song.loadFromJson(song.toLowerCase(), song.toLowerCase());
			reloadState();
		}
		catch(e)
		{
			Debug.logTrace('ERROR! $e');

			var errorStr:String = e.toString();
			if(errorStr.startsWith('[lime.utils.Assets] ERROR:')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(Paths.formatToSongPath(PlayState.SONG.song)), errorStr.length-1); //Missing chart
			
			if(missingText == null)
			{
				missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
				missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				missingText.scrollFactor.set();
				add(missingText);
			}
			else missingTextTimer.cancel();

			missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
			missingText.screenCenter(Y);

			missingTextTimer = new FlxTimer().start(5, function(tmr:FlxTimer) {
				remove(missingText);
				missingText.destroy();
			});
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
	}

	function reloadState():Void
	{
		LoadingState.loadAndSwitchState(new ChartingState(), true);
	}

	function autosaveSong():Void
	{
		FlxG.save.data.autosave = haxe.Json.stringify({
			"song": _song
		});
		FlxG.save.flush();
	}

	function clearEvents() {
		_song.events = [];
		updateGrid();
	}

	private function saveLevel()
	{
		if(_song.events != null && _song.events.length > 1) _song.events.sort(sortByTime);
		var json = {
			"song": _song
		};

		var data:String = haxe.Json.stringify(json, "\t");

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), Paths.formatToSongPath(_song.songId) + ".json");
		}
	}

	function sortByTime(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	private function saveEvents()
	{
		if(_song.events != null && _song.events.length > 1) _song.events.sort(sortByTime);
		var eventsSong:Dynamic = {
			events: _song.events
		};
		var json = {
			"song": eventsSong
		}

		var data:String = haxe.Json.stringify(json, "\t");

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), "events.json");
		}
	}

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved LEVEL DATA.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	function onSaveError(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving Level data");
	}

	function getSectionBeats(?section:Null<Int> = null)
	{
		if (section == null) section = curSec;
		var val:Null<Float> = null;
		
		if(_song.notes[section] != null) val = _song.notes[section].sectionBeats;
		return val != null ? val : 4;
	}
}

class AttachedFlxText extends FlxText
{
	public var sprTracker:FlxSprite;
	public var xAdd:Float = 0;
	public var yAdd:Float = 0;

	public function new(X:Float = 0, Y:Float = 0, FieldWidth:Float = 0, ?Text:String, Size:Int = 8, EmbeddedFont:Bool = true) {
		super(X, Y, FieldWidth, Text, Size, EmbeddedFont);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null) {
			setPosition(sprTracker.x + xAdd, sprTracker.y + yAdd);
			angle = sprTracker.angle;
			alpha = sprTracker.alpha;
		}
	}
}

class ChartEditorExitSubstate extends MusicBeatSubstate
{
    var exitFunc:Void->Void;
    override public function new(funcOnExit:Void->Void)
    {
        exitFunc = funcOnExit;
        super();
    }
    
    override public function create()
    {
        super.create();

        var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		bg.scale.set(1.2, 1.2);
		add(bg);
        FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});


        var warning:FlxText = new FlxText(0, 0, 0, 'You have unsaved changes!\nAre you sure you want to exit?', 48);
        warning.alignment = CENTER;
        warning.screenCenter();
        //warning.y += 50;
        add(warning);

        var goBackButton:FlxUIButton = new FlxUIButton(0, 500, 'Go Back', function()
        {
            close();
        });
        goBackButton.scale.set(2.5, 2.5);
        goBackButton.updateHitbox();
        goBackButton.label.size = 12;
        goBackButton.autoCenterLabel();
        goBackButton.x = (FlxG.width*0.3)-(goBackButton.width*0.5);
        add(goBackButton);
        
        var exit:FlxUIButton = new FlxUIButton(0, 500, 'Exit without saving', function()
        {
            exitFunc();
        });
        exit.scale.set(2.5, 2.5);
        exit.updateHitbox();
        exit.label.size = 12;
        exit.label.fieldWidth = exit.width;
        exit.autoCenterLabel();
        
        exit.x = (FlxG.width*0.7)-(exit.width*0.5);
        add(exit);

        cameras = [FlxG.cameras.list[FlxG.cameras.list.length-1]];
    }
}