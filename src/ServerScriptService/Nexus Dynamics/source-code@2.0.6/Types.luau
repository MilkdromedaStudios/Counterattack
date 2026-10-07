export type Scope = {
	GiveTask : (self: Scope, task: any) -> (),
	DoCleaningByType : (self: Scope) -> (),
	DoCleaning : (self: Scope) -> ()
}


export type Maid = {
	new : () -> Scope
}


export type CustomScriptSignal = {
	Event: RBXScriptSignal,

	Fire: (self: CustomScriptSignal, ...any) -> (),
	Connect: (self: CustomScriptSignal, func: (...any) -> RBXScriptConnection) -> RBXScriptConnection,
	ConnectParallel: (self: CustomScriptSignal, func: (...any) -> RBXScriptConnection) -> RBXScriptConnection,
	Once: (self: CustomScriptSignal, func: (...any) -> ()) -> RBXScriptConnection,
	Wait: (self: CustomScriptSignal) -> ...any,
}


export type Signal = {
	new : () -> CustomScriptSignal
}


export type Cache = (name: string) -> {any}


export type Changed = {
	new: (table: {any}) -> {any}
}


export type LogEntry = {
	MessageType: Enum.MessageType,
	Message: string,
	Timestamp: string,
}


export type Log = {
	Capture: (self: Log, message: string, messageType: Enum.MessageType) -> LogEntry,
	GetLogHistory: (self: Log) -> {LogEntry},
}


export type Util = {
	GetDeveloperId: () -> number,
	GetChatColor: ((username: string) -> Color3) & ((userId: number) -> Color3),	
	GetLocalTime: (clockStyle: number?) -> string,
	ConvertToLocalTime: (unixtimestamp: number, clockStyle: number?) -> string,
	GetBrickColors: () -> {[string]: Color3},
	FilterText: (text: string, fromUserId: number) -> string,
	PagesToTable: (pages: Pages) -> {any},
}


export type BanConfigType = {
	UserIds: {number},
	Duration: number,
	DisplayReason: string,
	PrivateReason: string,
	ExcluseAltAccounts: boolean?,
	ApplyToUniverse: boolean,
}


export type BanService = {
	IsBanned: ( self: BanService, userId: number ) -> (),

	PlaceBan: ( self: BanService, userIds: {number}, reason: string?, duration: number?) -> (),
	UniverseBan: ( self: BanService, userIds: {number}, reason: string?, duration: number?) -> (),
	UnBan: ( self: BanService, userIds: {number} ) -> (),

	PlaceBanned: CustomScriptSignal,
	UniverseBanned: CustomScriptSignal,
	UnBanned: CustomScriptSignal,
}


export type  GhostService = {
	IsGhosted: (self: GhostService, player: Player) -> (),

	RefreshPlayer: (self: GhostService, player: Player) -> (),
	GhostAsync: (self: GhostService, player: Player) -> (),
	UnghostAsync: (self: GhostService, player: Player) -> (),

	Ghosted: CustomScriptSignal,
	Unghosted: CustomScriptSignal,
}


export type RankTemplate = {
	Ranks: {{any}| string},
	Assign: {
		Assets: {[number]:string},
		Gamepasses:{[number]:string},
		Groups:{[number]:{[number]:string}},
	},
}


export type RankData = {
	Name: string,
	Id: number,
}


export type RankService = {
	AutoRankOwner: boolean,
	RankList: RankTemplate,

	RefreshRanks: (self: RankService) -> RankService,
	GetRankInfos: (self: RankService) -> {RankData},
	GetRankInfo: (self: RankService, identity: string | number) -> RankData,

	GetRankByUsername: (self: RankService, name: string) -> RankData,
	GetRankByUserId: (self: RankService, id: number) -> RankData,
	Grant: (self: RankService, userId: number, rankName: string) -> (),
	GrantT: (self: RankService, userId: number, rankName: string) -> (),
	Revoke: (self: RankService, userId: number) -> (),
	RevokeT: (self: RankService, userId: number) -> (),

	Granted: CustomScriptSignal,
	Revoked: CustomScriptSignal,
	Refreshed: CustomScriptSignal,
}


export type StaticRenderEffects = "None" | "GrayScale" | "Saturate" | "Contrast" | "Invert" | "Tint"


export type LiveRenderEffects = "None" | "Disco" | "Retro"


export type RenderService = {
	StaticEffect: (self: RenderService, name: StaticRenderEffects, properties: {[string]:any}?) -> RenderService,
	UnStaticEffect: (self: RenderService, name: StaticRenderEffects) -> RenderService,
	LiveEffect: (self: RenderService, name: LiveRenderEffects, properties: {[string]:any}?) -> RenderService,
	UnLiveEffect: (self: RenderService, name: LiveRenderEffects) -> RenderService,
}


export type ServerService = {
	ServerLock: boolean,
	ServerLockRank: string,

	JoinPlayer: (self: ServerService, senderId: number, userId: number) -> ServerService,
	Shutdown: (self: ServerService) -> ServerService,
	Migrate: (self: ServerService) -> ServerService,
	UniversalShutdown: (self: ServerService) -> ServerService,
	UniversalMigrate: (self: ServerService) -> ServerService,

	IsServerLocked: (self: ServerService) -> ServerService,
	Lock: (self: ServerService, lock: boolean, rankName: string?) -> ServerService,
	UniversalLock: (self: ServerService, lock: boolean, rankName: string?) -> ServerService,

	ServerLocked: CustomScriptSignal,
	ServerUnlocked: CustomScriptSignal,
}


export type UserRegistery = {
	UserSettings: UserSettings,
	ColorSettings: ColorSettings,
	BuildInfo: BuildInfo
}


export type UserRegisteryService = {
	GetAsync: (self: UserRegisteryService, userId: number) -> UserRegistery,
	SetAsync: (self: UserRegisteryService, userId: number, data: any) -> (),
	RemoveAsync: (self: UserRegisteryService, userId: number) -> (),
	UpdateAsync: (self: UserRegisteryService, userId: number, callback: (data: any) -> any?) -> ()
}


export type CommandType = "All" | "Built-In" | "Server" | "Client" | "Server Built-In" | "Client Built-In" | "Custom" | "Server Custom" | "Client Custom" 


export type Command = {
	Name: string,
	Description: string,
	Aliases: {string},

	--

	Rank: number,
	RankName: string,
	CaseSensitive: boolean,
	Loopable: boolean,
	Frequency: number,
	RunContext: Enum.RunContext?,

	--

	Arguments: {string},

	PreFunction: () -> (),
	Function: ( speaker: Player, args: {any} ) -> (),
	UnFunction: ( speaker: Player, args: {any} ) -> (),
}


export type CommandConfig = {
	HasPrefix: boolean,
	Command: string,
	CastType: "Run" | "Undo" | "Loop" | "Unloop",
	Qualifiers: {[number]:{[number]:string}},
}


export type CommandService = {
	GetCommandInfoAsync: (self: CommandService, name: string) -> Command,
	GetCommandList: (self: CommandService, type: CommandType) -> {Command},
	Request: (self: CommandService, speaker: Player, text: string) -> (CommandConfig, Command),
	Cast: (self: CommandService, speaker: Player, commandConfig: CommandType, commandDict: Command) -> (),

	CommandList: {
		["server@built-in"]: { Command },  
		["client@built-in"]: { Command },  
		["server@custom"]: { Command },  
		["client@custom"]: { Command },  
	}
}


export type FormatAI = {
	_rules: any,
	_flags: any,

	IsolateCommands: (self: FormatAI, text: string) -> {string},
	Read: (self: FormatAI, text: string) -> CommandConfig,
	Build: (self: FormatAI, speaker: Player, config: CommandConfig, commandDict: Command) -> (),
	Obtain: (self: FormatAI, speaker: Player, qualifierType: string, input: string) -> any,

	--

	GetQualifierType: (self: FormatAI, text: string) -> string
}


export type UserSettings = {
	Alerts: boolean,
	Autofill: boolean,
	AvgPing: boolean,
	ClockEnabled: boolean,
	ColorWheelOutput: Color3,
	CommandPrompt: string,
	DebugbarEnabled: boolean,
	Draggable: boolean,
	Errors: boolean,
	FPS: boolean,
	FlyPromptEnabled: boolean,
	MemoryUsage: boolean,
	Menu: string,
	NotificationPosition: string,
	NotificationsEnabled: boolean,
	PreviewIcons: boolean,
	Region: boolean,
	Shell: string,
	Suggestions: boolean,
	Theme: string,
	TopbarEnabled: boolean,
	TopbarPosition: string,
	Transparency: number,
	Use24HourClock: boolean,
	Version: boolean,
	Warnings: boolean
}


export type ColorSettings = {
	["--Accent"]: Color3,
	["--Accent-Text-Color"]: Color3,
	["--AccountTab-Background"]: Color3,
	["--AccountTab-Background-Active"]: Color3,
	["--AccountTab-Background-Hover"]: Color3,
	["--AccountTab-Border"]: Color3,
	["--AccountTab-Icon-Color"]: Color3,
	["--AccountTab-Text-Color"]: Color3,
	["--Background"]: Color3,
	["--Border"]: Color3,
	["--Bottom-Background"]: Color3,
	["--Bottom-Border"]: Color3,
	["--Button-Background"]: Color3,
	["--Button-Border"]: Color3,
	["--Button-Text-Color"]: Color3,
	["--Clock-Text-Color"]: Color3,
	["--Close"]: Color3,
	["--Default-Account"]: Color3,
	["--Description-Text-Color"]: Color3,
	["--Dropdown-Background"]: Color3,
	["--Dropdown-Border"]: Color3,
	["--Dropdown-Text-Color"]: Color3,
	["--Error"]: Color3,
	["--Option-Selected"]: Color3,
	["--Primary-Text-Color"]: Color3,
	["--Profile-Background"]: Color3,
	["--Profile-Card-Color"]: Color3,
	["--Ribbon-Background"]: Color3,
	["--Ribbon-Border"]: Color3,
	["--ScrollBar"]: Color3,
	["--Secondary-Text-Color"]: Color3,
	["--Shadow"]: Color3,
	["--Sidebar-Background"]: Color3,
	["--Sidebar-Button-Even"]: Color3,
	["--Sidebar-Button-Odd"]: Color3,
	["--Sidebar-Icon"]: Color3,
	["--Sidebar-Icon-Active"]: Color3,
	["--Sidebar-Text"]: Color3,
	["--Sidebar-Text-Active"]: Color3,
	["--Skybox-Index-Background"]: Color3,
	["--Slider-Background"]: Color3,
	["--Slider-Filler"]: Color3,
	["--Slider-Head"]: Color3,
	["--Slider-Text-Color"]: Color3,
	["--Tab-Background"]: Color3,
	["--Tab-Background-Active"]: Color3,
	["--Tab-Background-Hover"]: Color3,
	["--Tab-Border"]: Color3,
	["--Tab-Icon-Color"]: Color3,
	["--Tab-Text-Color"]: Color3,
	["--TextBox-Background"]: Color3,
	["--TextBox-Border"]: Color3,
	["--TextBox-Placeholder-Color"]: Color3,
	["--TextBox-Text-Color"]: Color3,
	["--Tint"]: Color3,
	["--Title-Background"]: Color3,
	["--Toggle-Background-Off"]: Color3,
	["--Toggle-Background-On"]: Color3,
	["--Toggle-Head-Off"]: Color3,
	["--Toggle-Head-On"]: Color3,
	["--Top-Background"]: Color3,
	["--Top-Border"]: Color3,
	["--Warning"]: Color3
}


export type Color = 
	"--Accent"                       | "--Error"                 | "--Warning"                 | "--Background"            | "--Top-Background" | 
"--Top-Border"                   | "--Ribbon-Background"     | "--Ribbon-Border"           | "--Bottom-Background"     | "--Bottom-Border" | 
"--Close"                        | "--Sidebar-Background"    | "--Sidebar-Button-Odd"      | "--Sidebar-Button-Even"   | "--Sidebar-Icon" | 
"--Sidebar-Icon-Active"          | "--Sidebar-Text"          | "--Sidebar-Text-Active"     | "--Sidebar-Button-Active" | "--Title-Background" | 
"--Primary-Text-Color"           | "--Button-Background"     | "--Shadow"                  | "--Toggle-Head-Off"       | "--AccountTab-Background-Hover" |
"--Toggle-Head-On"               | "--Toggle-Background-Off" | "--Toggle-Background-On"    | "--Option-Selected"       | "--Slider-Head" | 
"--Slider-Background"            | "--Slider-Filler"         | "--Default-Account"         | "--Border"                | "--ScrollBar" | 
"--Accent-Text-Color"            | "--Profile-Background"    | "--Skybox-Index-Background" | "--Button-Border"         | "--Description-Text-Color" | 
"--Secondary-Text-Color"         | "--Tab-Background"        | "--Tab-Background-Active"   | "--Tab-Border"            | "--AccountTab-Background" | 
"--AccountTab-Background-Active" | "--AccountTab-Border"     | "--Dropdown-Background"     | "--Dropdown-Border"       | "--TextBox-Background" | 
"--TextBox-Border"               | "--Button-Text-Color"     | "--Dropdown-Text-Color"     | "--TextBox-Text-Color"    | "--TextBox-Placeholder-Color" | 
"--Slider-Text-Color"            | "--Tab-Text-Color"        | "--Tab-Icon-Color"          | "--AccountTab-Text-Color" | "--AccountTab-Icon-Color" | 
"--Profile-Card-Color"           | "--Clock-Text-Color"      | "--Tab-Background-Hover"


export type BuildInfo = {
	StudioVersion: string,
	ClientVersion: string,
	ModelId: string,
	PackageId: string,
	Version: string,
	BanService: string,
	CommandService: string,
	GhostService: string,
	NotificationService: string,
	RankService: string,
	RenderService: string,
	ServerService: string
}


export type Connector = {
	File: typeof(script.Parent.Parent),
	Custom: typeof(script.Parent.Parent.Custom),
	
	Package: typeof(script.Parent),
	Libraries: typeof(script.Parent.Libraries),
	Services: typeof(script.Parent.Services),
	Templates: typeof(script.Parent.Templates),
	
	Cache: Cache,
	Changed: Changed,
	Log: Log,
	Maid: Maid,
	Signal: Signal,
	Util: Util,
	
	DataStore: DataStore,
	Signals: typeof(script.Parent.Signals),
	
	Elapsed: number,
	Scope: Scope,
	
	Switch: (case: any) -> (cases: {[string]: () -> any}) -> any,
}


return nil