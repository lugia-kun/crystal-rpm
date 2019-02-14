module RPM
  # :nodoc:
  macro define_version(const, version)
    {{const}} = {{version}}
  end

  # :nodoc:
  macro define_version_constants(version)
    # The version of librpm which is used at compiled time.
    PKGVERSION = {{version}}

    {% splitted = version.split(".") %}

    # Major version part of `PKGVERSION`
    PKGVERSION_MAJOR = {{splitted[0].id}}

    # Minor version part of `PKGVERSION`
    PKGVERSION_MINOR = {{splitted[1].id}}

    # Patch version part of `PKGVERSION`
    PKGVERSION_PATCH = {{splitted[2].id}}

    # If `PKGVERSION` has 4 or more parts, `PKGVERSION_EXTRA` contains it.
    # For example, if the version is `4.14.2.1`, `PKGVERSION_EXTRA` will be
    # set to `"1"` (note that string).
    #
    # `PKGVERSION_EXTRA` will be `nil` if no such parts.
    {% if splitted.size >= 4 %}
      PKGVERSION_EXTRA = {{splitted[3..-1].join(".")}}
    {% else %}
      PKGVERSION_EXTRA = nil
    {% end %}
  end

  define_version_constants({{`pkg-config rpm --modversion`.chomp.stringify}})

  # :nodoc:
  macro define_3_parts_version(maj, min, pat)
    # Comparable version of `PKGVERSION` by `compare_versions()`.
    define_version(PKGVERSION_COMP, {{[maj, min, pat].join(".")}})
  end

  define_3_parts_version({{PKGVERSION_MAJOR}}, {{PKGVERSION_MINOR}}, {{PKGVERSION_PATCH}})

  @[Link(ldflags: "`pkg-config rpm --libs`")]
  lib LibRPM
    # ## Internal types

    alias Count = UInt32
    alias RPMFlags = UInt32
    alias TagVal = Int32
    alias DbiTagVal = TagVal
    alias Loff = UInt64

    alias Int = LibC::Int
    alias UInt = LibC::UInt
    alias SizeT = LibC::SizeT

    type Header = Pointer(Void)
    type HeaderIterator = Pointer(Void)
    alias Transaction = Pointer(Void)
    type Database = Pointer(Void)
    type DatabaseMatchIterator = Pointer(Void)
    type MacroContext = Pointer(Void)
    type Problem = Pointer(Void)
    alias FnpyKey = Pointer(Void)
    type DependencySet = Pointer(Void)
    type ProblemSet = Pointer(Void)
    type ProblemSetIterator = Pointer(Void)
    type TagData = Pointer(Void)
    type Relocation = Pointer(Void)
    type FD = Pointer(Void)

    alias RPMDs = DependencySet
    alias RPMPs = ProblemSet
    alias RPMPsi = ProblemSetIterator
    alias RPMTd = TagData
    alias RPMTs = Transaction
    alias RPMDb = Database
    alias RPMDbMatchIterator = DatabaseMatchIterator

    alias ErrorMsg = Pointer(UInt8)

    enum RC
      OK, NOTFOUND, FAIL, NOTTRUSTED, NOKEY
    end

    # ## Callback APIs.

    @[Flags]
    enum CallbackType : RPMFlags
      UNKNOWN            = 0
      INST_PROGRESS      = (1_u32 << 0)
      INST_START         = (1_u32 << 1)
      INST_OPEN_FILE     = (1_u32 << 2)
      INST_CLOSE_FILE    = (1_u32 << 3)
      TRANS_PROGRESS     = (1_u32 << 4)
      TRANS_START        = (1_u32 << 5)
      TRANS_STOP         = (1_u32 << 6)
      UNINST_PROGRESS    = (1_u32 << 7)
      UNINST_START       = (1_u32 << 8)
      UNINST_STOP        = (1_u32 << 9)
      REPACKAGE_PROGRESS = (1_u32 << 10)
      REPACKAGE_START    = (1_u32 << 11)
      REPACKAGE_STOP     = (1_u32 << 12)
      UNPACK_ERROR       = (1_u32 << 13)
      CPIO_ERROR         = (1_u32 << 14)
      SCRIPT_ERROR       = (1_u32 << 15)
    end

    alias CallbackData = Pointer(Void)
    alias CallbackFunction = (LibRPM::Header, CallbackType, Loff, Loff, FnpyKey, CallbackData) -> Pointer(Void)

    # ## CLI APIs.
    $rpmcliPackagesTotal : Int
    fun rpmShowProgress(LibRPM::Header, CallbackType, Loff, Loff, FnpyKey, Void*) : Pointer(Void)

    # ## DB APIs.

    enum MireMode
      DEFAULT = 0
      STRCMP  = 1
      REGEX   = 2
      GLOB    = 3
    end

    fun rpmdbCountPackages(RPMDb, UInt8*) : Int
    fun rpmdbGetIteratorOffset(RPMDbMatchIterator) : UInt
    fun rpmdbGetIteratorCount(RPMDbMatchIterator) : Int
    fun rpmdbSetIteratorRE(RPMDbMatchIterator, TagVal, MireMode, UInt8*) : Int

    fun rpmdbInitIterator(RPMDb, DbiTagVal, Void*, SizeT) : RPMDbMatchIterator

    fun rpmdbNextIterator(RPMDbMatchIterator) : Header
    fun rpmdbFreeIterator(RPMDbMatchIterator) : Void

    # ## Dependency Set APIs.

    @[Flags]
    enum Sense : RPMFlags
      ANY           = 0
      LESS          = (1_u32 << 1)
      GREATER       = (1_u32 << 2)
      EQUAL         = (1_u32 << 3)
      POSTTRANS     = (1_u32 << 5)
      PREREQ        = (1_u32 << 6)
      PRETRANS      = (1_u32 << 7)
      INTERP        = (1_u32 << 8)
      SCRIPT_PRE    = (1_u32 << 9)
      SCRIPT_POST   = (1_u32 << 10)
      SCRIPT_PREUN  = (1_u32 << 11)
      SCRIPT_POSTUN = (1_u32 << 12)
      SCRIPT_VERIFY = (1_u32 << 13)
      FIND_REQUIRES = (1_u32 << 14)
      FIND_PROVIDES = (1_u32 << 15)
      TRIGGERIN     = (1_u32 << 16)
      TRIGGERUN     = (1_u32 << 17)
      TRIGGERPOSTUN = (1_u32 << 18)
      MISSINGOK     = (1_u32 << 19)
      RPMLIB        = (1_u32 << 24)
      TRIGGERPREIN  = (1_u32 << 25)
      KEYRING       = (1_u32 << 26)
      CONFIG        = (1_u32 << 28)
    end

    fun rpmdsSingle(TagVal, UInt8*, UInt8*, Sense) : DependencySet
    fun rpmdsCompare(DependencySet, DependencySet) : Int
    fun rpmdsCount(DependencySet) : Int
    fun rpmdsCurrent(DependencySet) : DependencySet
    fun rpmdsInstance(DependencySet) : UInt
    fun rpmdsIx(DependencySet) : Int
    fun rpmdsSetIx(DependencySet, Int) : Int
    fun rpmdsFree(DependencySet) : DependencySet
    fun rpmdsLink(DependencySet) : DependencySet
    fun rpmdsMerge(DependencySet*, DependencySet) : Int
    fun rpmdsTagN(DependencySet) : TagVal
    fun rpmdsTagTi(DependencySet) : TagVal
    fun rpmdsTi(DependencySet) : Int
    fun rpmdsN(DependencySet) : UInt8*
    fun rpmdsDNEVR(DependencySet) : UInt8*
    fun rpmdsNext(DependencySet) : Int

    # ## File Info Set APIs.

    @[Flags]
    enum FileAttrs : RPMFlags
      NONE      = 0
      CONFIG    = (1_u32 << 0)
      DOC       = (1_u32 << 1)
      ICON      = (1_u32 << 2)
      MISSINGOK = (1_u32 << 3)
      NOREPLACE = (1_u32 << 4)
      SPECFILE  = (1_u32 << 5)
      GHOST     = (1_u32 << 6)
      LICENSE   = (1_u32 << 7)
      README    = (1_u32 << 8)
      EXCLUDE   = (1_u32 << 9)
      UNPATCHED = (1_u32 << 10)
      PUBKEY    = (1_u32 << 11)
    end

    enum FileState
      MISSING      = -1
      NORMAL       =  0
      REPLACED     =  1
      NOTINSTALLED =  2

      NETSHARED  = 3
      WRONGCOLOR = 4
    end

    # ## Tag APIs.
    enum Tag : TagVal
      NotFound         =  -1
      HeaderImage      =  61
      HeaderSignatures =  62
      HeaderImmutable  =  63
      HeaderRegions    =  64
      HeaderI18nTable  = 100

      SigBase         = 256
      SigSize         = SigBase + 1
      SigLEMD5_1      = SigBase + 2
      SigPGP          = SigBase + 3
      SigLEMD5_2      = SigBase + 4
      SigMD5          = SigBase + 5
      SigGPG          = SigBase + 6
      SigPGP5         = SigBase + 7
      BadSHA1_1       = SigBase + 8
      BadSHA1_2       = SigBase + 9
      Pubkeys         = SigBase + 10
      DSAHeader       = SigBase + 11
      RSAHeader       = SigBase + 12
      SHA1Header      = SigBase + 13
      LongSigSize     = SigBase + 14
      LongArchiveSize = SigBase + 15
      SHA256Header    = SigBase + 17

      Name                        = 1000
      Version                     = 1001
      Release                     = 1002
      Epoch                       = 1003
      Summary                     = 1004
      Description                 = 1005
      BuildTime                   = 1006
      BuildHost                   = 1007
      InstallTime                 = 1008
      Size                        = 1009
      Distribution                = 1010
      Vendor                      = 1011
      GIF                         = 1012
      XPM                         = 1013
      License                     = 1014
      Packager                    = 1015
      Group                       = 1016
      ChangeLog                   = 1017
      Source                      = 1018
      Patch                       = 1019
      URL                         = 1020
      OS                          = 1021
      Arch                        = 1022
      PreIn                       = 1023
      PostIn                      = 1024
      PreUn                       = 1025
      PostUn                      = 1026
      OldFilenames                = 1027
      FileSizes                   = 1028
      FileStates                  = 1029
      FileModes                   = 1030
      FileUIDs                    = 1031
      FileGIDs                    = 1032
      FileRDEVs                   = 1033
      FileMTimes                  = 1034
      FileDigests                 = 1035
      FileLinkTos                 = 1036
      FileFlags                   = 1037
      Root                        = 1038
      FileUserName                = 1039
      FileGroupName               = 1040
      Exclude                     = 1041
      Exclusive                   = 1042
      Icon                        = 1043
      SourceRPM                   = 1044
      FileVerifyFlags             = 1045
      ArchiveSize                 = 1046
      ProvideName                 = 1047
      RequireFlags                = 1048
      RequireName                 = 1049
      RequireVersion              = 1050
      NoSource                    = 1051
      NoPatch                     = 1052
      ConflictFlags               = 1053
      ConflictName                = 1054
      ConflictVersion             = 1055
      DefaultPrefix               = 1056
      BuildRoot                   = 1057
      InstallPrefix               = 1058
      ExcludeArch                 = 1059
      ExcludeOS                   = 1060
      ExclusiveArch               = 1061
      ExclusiveOS                 = 1062
      AutoReqProv                 = 1063
      RPMVersion                  = 1064
      TriggerScripts              = 1065
      TriggerName                 = 1066
      TriggerVersion              = 1067
      TriggerFlags                = 1068
      TriggerIndex                = 1069
      VerifyScript                = 1079
      ChangeLogTime               = 1080
      ChangeLogName               = 1081
      ChangeLogText               = 1082
      BrokenMD5                   = 1083
      PreReq                      = 1084
      PreInProg                   = 1085
      PostInProg                  = 1086
      PreUnProg                   = 1087
      PostUnProg                  = 1088
      BuildArchs                  = 1089
      ObsoleteName                = 1090
      VerifyScriptProg            = 1091
      TriggerScriptProg           = 1092
      DocDir                      = 1093
      Cookie                      = 1094
      FileDevices                 = 1095
      FileInodes                  = 1096
      FileLangs                   = 1097
      Prefixes                    = 1098
      InstPrefixes                = 1099
      TriggerIn                   = 1100
      TriggerUn                   = 1101
      TriggerPostUn               = 1102
      AutoReq                     = 1103
      AutoProv                    = 1104
      Capability                  = 1105
      SourcePackage               = 1106
      OldOrigFileNames            = 1107
      BuildPreReq                 = 1108
      BuildRequires               = 1109
      BuildConflicts              = 1110
      BuildMacros                 = 1111
      ProvideFlags                = 1112
      ProvideVersion              = 1113
      ObsoleteFlags               = 1114
      ObsoleteVersion             = 1115
      DirIndexes                  = 1116
      BaseNames                   = 1117
      DirNames                    = 1118
      OrigDirIndexes              = 1119
      OrigBaseNames               = 1120
      OrigDirNames                = 1121
      OptFlags                    = 1122
      DistURL                     = 1123
      PayloadFormat               = 1124
      PayloadCompressor           = 1125
      PayloadFlags                = 1126
      InstallColor                = 1127
      InstallTid                  = 1128
      RemoveTid                   = 1129
      SHA1RHN                     = 1130
      RHNPlatform                 = 1131
      Platform                    = 1132
      PatchesName                 = 1133
      PatchesFlags                = 1134
      PatchesVersion              = 1135
      CacheCTime                  = 1136
      CachePkgPath                = 1137
      CachePkgSize                = 1138
      CachePkgMTime               = 1139
      FileColors                  = 1140
      FileClass                   = 1141
      ClassDict                   = 1142
      FileDependsX                = 1143
      FileDependsN                = 1144
      DependsDict                 = 1145
      SourcePkgID                 = 1146
      FileContexts                = 1147
      FSContexts                  = 1148
      Recontexts                  = 1149
      Policies                    = 1150
      PreTrans                    = 1151
      PostTrans                   = 1152
      PreTransProg                = 1153
      PostTransProg               = 1154
      DistTag                     = 1155
      OldSuggestsName             = 1156
      OldSuggestsVersion          = 1157
      OldSuggestsFlags            = 1158
      OldEnhancesName             = 1159
      OldEnhancesVersion          = 1160
      OldEnhancesFlags            = 1161
      Priority                    = 1162
      CVSID                       = 1163
      BLinkPkgID                  = 1164
      BLinkHdrID                  = 1165
      BLinkNevRA                  = 1166
      FLinkPkgID                  = 1167
      FLinkHdrID                  = 1168
      FLinkNevRA                  = 1169
      PackageOrigin               = 1170
      TriggerPreIn                = 1171
      BuildSuggests               = 1172
      BuildEnhances               = 1173
      ScriptStates                = 1174
      ScriptMetrics               = 1175
      BuildCPUClock               = 1176
      FileDigestAlgos             = 1177
      Variants                    = 1178
      XMajor                      = 1179
      XMinor                      = 1180
      RepoTag                     = 1181
      Keywords                    = 1182
      BuildPlatforms              = 1183
      PackageColor                = 1184
      PackagePrefColor            = 1185
      XAttrsDict                  = 1186
      FileXAttrsX                 = 1187
      DepAttrsDict                = 1188
      ConflictAttrsX              = 1189
      ObsoleteAttrsX              = 1190
      ProvideAttrsX               = 1191
      RequireAttrsX               = 1192
      BuildProvides               = 1193
      BuildObsoletes              = 1194
      DBInstance                  = 1195
      NVRA                        = 1196
      FileNames                   = 5000
      FileProvide                 = 5001
      FileRequire                 = 5002
      FSNames                     = 5003
      FSSizes                     = 5004
      TriggerConds                = 5005
      TriggerType                 = 5006
      OrigFileNames               = 5007
      LongFileSizes               = 5008
      LongSize                    = 5009
      FileCaps                    = 5010
      FileDigestAlgo              = 5011
      BugURL                      = 5012
      EVR                         = 5013
      NVR                         = 5014
      NEVR                        = 5015
      NEVRA                       = 5016
      HeaderColor                 = 5017
      Verbose                     = 5018
      EpochNum                    = 5019
      PreInFlags                  = 5020
      PostInFlags                 = 5021
      PreUnFlags                  = 5022
      PostUnFlags                 = 5023
      PreTransFlags               = 5024
      PostTransFlags              = 5025
      VerifyScriptFlags           = 5026
      TriggerScriptFlags          = 5027
      Collections                 = 5029
      PolicyNames                 = 5030
      PolicyTypes                 = 5031
      PolicyTypesIndexes          = 5032
      PolicyFlags                 = 5033
      VCS                         = 5034
      OrderName                   = 5035
      OrderVersion                = 5036
      OrderFlags                  = 5037
      MSSFManifest                = 5038
      MSSFDomain                  = 5039
      InstFileNames               = 5040
      RequireNEVRS                = 5041
      ProvideNEVRS                = 5042
      ObsoleteNEVRS               = 5043
      ConflictNEVRS               = 5044
      FileNLinks                  = 5045
      RecommendName               = 5046
      RecommendVersion            = 5047
      RecommendFlags              = 5048
      SuggestName                 = 5049
      SuggestVersion              = 5050
      SuggestFlags                = 5051
      SupplementName              = 5052
      SupplementVersion           = 5053
      SupplementFlags             = 5054
      EnhanceName                 = 5055
      EnhanceVersion              = 5056
      EnhanceFlags                = 5057
      RecommendNEVRS              = 5058
      SuggestNEVRS                = 5059
      SupplementNEVRS             = 5060
      EnhanceNEVRS                = 5061
      Encoding                    = 5062
      FileTriggerIn               = 5063
      FileTriggerUn               = 5064
      FileTriggerPostUn           = 5065
      FileTriggerScripts          = 5066
      FileTriggerScriptProg       = 5067
      FileTriggerScriptFlags      = 5068
      FileTriggerName             = 5069
      FileTriggerIndex            = 5070
      FileTriggerVersion          = 5071
      FileTriggerFlags            = 5072
      TransfileTriggerIn          = 5073
      TransfileTriggerUn          = 5074
      TransfileTriggerPostUn      = 5075
      TransfileTriggerScripts     = 5076
      TransfileTriggerScriptProg  = 5077
      TransfileTriggerScriptFlags = 5078
      TransfileTriggerName        = 5079
      TransfileTriggerIndex       = 5080
      TransfileTriggerVersion     = 5081
      TransfileTriggerFlags       = 5082
      RemovePathPostFixes         = 5083
      FileTriggerPriorities       = 5084
      TransfileTriggerPriorities  = 5085
      FileTriggerConds            = 5086
      FileTriggerType             = 5087
      TransfileTriggerConds       = 5088
      TransfileTriggerType        = 5089
      FileSignatures              = 5090
      FileSignatureLength         = 5091
      PayloadDigest               = 5092
      PayloadDigestAlgo           = 5093

      FirstFreeTag
    end

    enum DbiTag : DbiTagVal
      Packages     = 0
      Label        = 2
      Name         = Tag::Name
      BaseNames    = Tag::BaseNames
      Group        = Tag::Group
      RequireName  = Tag::RequireName
      ProvideName  = Tag::ProvideName
      ConflictName = Tag::ConflictName
      ObsoleteName = Tag::ObsoleteName
      TriggerName  = Tag::TriggerName
      DirNames     = Tag::DirNames
      InstallTid   = Tag::InstallTid

      SigMD5          = Tag::SigMD5
      SHA1Header      = Tag::SHA1Header
      InstFileNames   = Tag::InstFileNames
      FileTriggerName = Tag::FileTriggerName

      TransFileTriggerName = Tag::TransfileTriggerName
      RecommendName        = Tag::RecommendName
      SuggestNmae          = Tag::SuggestName
      SupplementName       = Tag::SupplementName

      EnhanceName = Tag::EnhanceName
    end

    @[Flags]
    enum TagReturnType : RPMFlags
      ANY     =           0
      SCALAR  = 0x0001_0000
      ARRAY   = 0x0002_0000
      MAPPING = 0x0004_0000
      MASK    = 0xFFFF_0000
    end

    enum TagType
      NULL         = 0,
      CHAR         = 1,
      INT8         = 2,
      INT16        = 3,
      INT32        = 4,
      INT64        = 5,
      STRING       = 6,
      BIN          = 7,
      STRING_ARRAY = 8,
      I18NSTRING   = 9
    end

    enum SubTagType
      REGION    = -10
      BIN_ARRAY = -11
      XREF      = -12
    end

    enum TagClass
      NULL, NUMERIC, STRING, BINARY
    end

    fun rpmTagGetName(TagVal) : Pointer(UInt8)
    fun rpmTagGetNames(TagData, Int) : Int
    fun rpmTagGetClass(TagVal) : TagClass
    fun rpmTagGetType(TagVal) : RPMFlags

    # These two functions are added on 4.9.0
    # Use RPM#tag_type and RPM#tag_get_return_type instead.
    fun rpmTagType(TagVal) : TagType
    fun rpmTagGetReturnType(TagVal) : TagReturnType

    # ## Header APIs.

    @[Flags]
    enum HeaderGetFlags : RPMFlags
      DEFAULT = 0
      MINMEM  = (1_u32 << 0)
      EXT     = (1_u32 << 1)
      RAW     = (1_u32 << 2)
      ALLOC   = (1_u32 << 3)
      ARGV    = (1_u32 << 4)
    end

    @[Flags]
    enum HeaderPutFlags : RPMFlags
      DEFAULT = 0
      APPEND  = (1_u32 << 0)
    end

    enum HeaderConvOps
      EXPANDFILELIST   = 0
      COMPRESSFILELIST = 1
      RETROFIT_V3      = 2
    end

    fun headerNew : Header
    fun headerFree(Header) : Header
    fun headerLink(Header) : Header

    fun headerGet(Header, TagVal, TagData, HeaderGetFlags) : Int
    fun headerGetString(Header, TagVal) : Pointer(UInt8)
    fun headerGetAsString(Header, TagVal) : Pointer(UInt8)
    fun headerPut(Header, TagData, HeaderPutFlags) : Int
    fun headerPutString(Header, TagVal, UInt8*) : Int
    fun headerPutUint32(Header, TagVal, UInt32*, Count) : Int
    fun headerFormat(Header, UInt8*, ErrorMsg*) : Pointer(UInt8)

    fun rpmReadPackageFile(Transaction, FD, UInt8*, Header*) : RC

    # ## IO APIs.
    fun Fopen(UInt8*, UInt8*) : FD
    fun Fclose(FD) : Void
    fun Ferror(FD) : Int
    fun fdDup(Int) : FD
    fun Fstrerror(FD) : Pointer(UInt8)
    fun fdLink(Void*) : FD

    # ## Library APIs.
    $rpmversion = RPMVERSION : Pointer(UInt8)
    $rpmEVR : Pointer(UInt8)

    fun rpmReadConficFiles(UInt8*, UInt8*) : Int
    fun rpmvercmp(UInt8*, UInt8*) : Int

    # ## Log APIs.

    RPMLOG_PREMASK = 0x07

    enum LogLvl
      EMERG   = 0
      ALERT   = 1
      CRIT    = 2
      ERR     = 3
      WARNING = 4
      NOTICE  = 5
      INFO    = 6
      DEBUG   = 7
    end

    fun rpmlogSetMask(Int) : Int
    fun rpmlogMessage : Pointer(UInt8)

    # ## Macro APIs.

    $macrofiles : Pointer(UInt8)

    RMIL_DEFAULT    = -15
    RMIL_MACROFILES = -13
    RMIL_RPMRC      = -11
    RMIL_CMDLINE    =  -7
    RMIL_TARBALL    =  -5
    RMIL_SPEC       =  -3
    RMIL_OLDSPEC    =  -1
    RMIL_GLOBAL     =   0

    # Use RPM#push_macro and RPM#pop_macro

    # These two functions are added at 4.14.0
    fun rpmPushMacro(MacroContext, UInt8*, UInt8*, UInt8*, Int) : Int
    fun rpmPopMacro(MacroContext, UInt8*) : Int

    # These two functions are removed at 4.14.0
    fun addMacro(MacroContext, UInt8*, UInt8*, UInt8*, Int) : Int
    fun delMacro(MacroContext, UInt8*) : Int

    fun rpmExpand(UInt8*, ...) : Pointer(UInt8)

    # ## Problem APIs.

    @[Flags]
    enum ProbFilterFlags : RPMFlags
      NONE            = 0
      IGNOREOS        = (1_u32 << 0)
      IGNOREARCH      = (1_u32 << 1)
      REPLACEPKG      = (1_u32 << 2)
      FORCERELOCATE   = (1_u32 << 3)
      REPLACENEWFILES = (1_u32 << 4)
      REPLACEOLDFILES = (1_u32 << 5)
      OLDPACKAGE      = (1_u32 << 6)
      DISKSPACE       = (1_u32 << 7)
      DISKNODES       = (1_u32 << 8)
    end

    enum ProblemType
      BADARCH
      BADOS
      PKG_INSTALLED
      BADRELOCATE
      REQUIRES
      CONFLICT
      NEW_FILE_CONFLICT
      FILE_CONFLICT
      OLDPACKAGE
      DISKSPACE
      DISKNODES
      OBSOLETES
    end

    {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
      fun rpmProblemCreate(ProblemType, UInt8*, FnpyKey, UInt8*, UInt8*, UInt8*, UInt64) : Problem
    {% else %}
      fun rpmProblemCreate(ProblemType, UInt8*, FnpyKey, UInt8*, UInt8*, UInt64) : Problem
    {% end %}

    fun rpmProblemFree(Problem) : Problem
    fun rpmProblemLink(Problem) : Problem
    fun rpmProblemGetType(Problem) : ProblemType
    fun rpmProblemGetKey(Problem) : FnpyKey
    fun rpmProblemGetStr(Problem) : Pointer(UInt8)
    fun rpmProblemString(Problem) : Pointer(UInt8)
    fun rpmProblemCompare(Problem, Problem) : Int

    # ## Problem Set APIs.

    fun rpmpsInitIterator(ProblemSet) : ProblemSetIterator
    fun rpmpsNextIterator(ProblemSetIterator) : Int
    fun rpmpsGetProblem(ProblemSetIterator) : Problem
    fun rpmpsFree(ProblemSet) : ProblemSet
    fun rpmpsFreeIterator(ProblemSetIterator) : ProblemSetIterator

    # ## TagData APIs.

    fun rpmtdNew : TagData
    fun rpmtdFree(TagData) : TagData
    fun rpmtdReset(TagData) : TagData
    fun rpmtdFreeData(TagData) : Void
    fun rpmtdCount(TagData) : UInt32
    fun rpmtdTag(TagData) : TagVal
    fun rpmtdType(TagData) : TagType

    fun rpmtdInit(TagData) : LibC::Int
    fun rpmtdNext(TagData) : LibC::Int
    fun rpmtdNextUint32(TagData) : Pointer(UInt32)
    fun rpmtdNextUint64(TagData) : Pointer(UInt64)
    fun rpmtdNextString(TagData) : Pointer(UInt8)
    fun rpmtdGetChar(TagData) : Pointer(UInt8)
    fun rpmtdGetUint16(TagData) : Pointer(UInt16)
    fun rpmtdGetUint32(TagData) : Pointer(UInt32)
    fun rpmtdGetUint64(TagData) : Pointer(UInt64)
    fun rpmtdGetString(TagData) : Pointer(UInt8)
    fun rpmtdGetNumber(TagData) : UInt64

    fun rpmtdFromUint8(TagData, TagVal, UInt8*, Count) : Int
    fun rpmtdFromUint16(TagData, TagVal, UInt16*, Count) : Int
    fun rpmtdFromUint32(TagData, TagVal, UInt32*, Count) : Int
    fun rpmtdFromUint64(TagData, TagVal, UInt64*, Count) : Int
    fun rpmtdFromString(TagData, TagVal, UInt8*) : Int
    fun rpmtdFromStringArray(TagData, TagVal, UInt8**, Count) : Int

    enum TagDataFormat
      STRING
      ARMOR
      BASE64
      PGPSIG
      DEPFLAGS
      FFLAGS
      PERMS
      TRIGGERTYPE
      XML
      OCTAL
      HEX
      DATE
      DAY
      SHESCAPE
      ARRAYSIZE
      DEPTYPE
      FSTATE
      VFLAGS
      EXPAND
      FSTATUS
    end

    fun rpmtdFormat(TagData, TagDataFormat, UInt8*) : Pointer(UInt8)

    # ## Transaction APIs.
    @[Flags]
    enum TransFlags : RPMFlags
      NONE            = 0
      TEST            = (1_u32 << 0)
      BUILD_PROBS     = (1_u32 << 1)
      NOSCRIPTS       = (1_u32 << 2)
      JUSTDB          = (1_u32 << 3)
      NOTRIGGERS      = (1_u32 << 4)
      NODOCS          = (1_u32 << 5)
      ALLFILES        = (1_u32 << 6)
      NOPLUGINS       = (1_u32 << 7)
      NOCONTEXTS      = (1_u32 << 8)
      NOCAPS          = (1_u32 << 9)
      NOTRIGGERPREIN  = (1_u32 << 16)
      NOPRE           = (1_u32 << 17)
      NOPOST          = (1_u32 << 18)
      NOTRIGGERIN     = (1_u32 << 19)
      NOTRIGGERUN     = (1_u32 << 20)
      NOPREUN         = (1_u32 << 21)
      NOPOSTUN        = (1_u32 << 22)
      NOTRIGGERPOSTUN = (1_u32 << 23)
      NOPRETRANS      = (1_u32 << 24)
      NOPOSTTRANS     = (1_u32 << 25)
      NOMD5           = (1_u32 << 27)
      NOFILEDIGEST    = (1_u32 << 27)
      NOCONFIGS       = (1_u32 << 30)
      DEPLOOPS        = (1_u32 << 31)
    end

    fun rpmtsCheck(Transaction) : Int
    fun rpmtsOrder(Transaction) : Int

    @[Raises]
    fun rpmtsRun(Transaction, ProblemSet, ProbFilterFlags) : Int

    fun rpmtsLink(Transaction) : Transaction
    fun rpmtsCloseDB(Transaction) : Int
    fun rpmtsOpenDB(Transaction, Int) : Int
    fun rpmtsInitDB(Transaction, Int) : Int
    fun rpmtsGetDBMode(Transaction) : Int
    fun rpmtsSetDBMode(Transaction, Int) : Int
    fun rpmtsRebuildDB(Transaction)
    fun rpmtsVerifyDB(Transaction)
    fun rpmtsInitIterator(Transaction, DbiTagVal, Void*, SizeT) : DatabaseMatchIterator
    fun rpmtsProblems(Transaction) : ProblemSet

    fun rpmtsClean(Transaction) : Void
    fun rpmtsFree(Transaction) : Transaction

    fun rpmtsSetNotifyCallback(Transaction, CallbackFunction, Relocation) : Int

    fun rpmtsRootDir(Transaction) : Pointer(UInt8)
    fun rpmtsSetRootDir(Transaction, UInt8*) : Int

    fun rpmtsGetRdb(Transaction) : Database

    fun rpmtsFlags(Transaction) : TransFlags
    fun rpmtsSetFlags(Transaction, TransFlags) : TransFlags

    fun rpmtsCreate : Transaction
    fun rpmtsAddInstallElement(Transaction, Header, FnpyKey, Int, Relocation) : Int
    fun rpmtsAddEraseElement(Transaction, Header, Int) : Int

    # ## RC
    fun rpmReadConfigFiles(UInt8*, UInt8*) : Int
  end # LibRPM

  # Exposed Types

  alias Tag = LibRPM::Tag
  alias TagValue = LibRPM::TagVal
  alias TagType = LibRPM::TagType
  alias TagReturnType = LibRPM::TagReturnType
  alias DbiTag = LibRPM::DbiTag
  alias DbiTagValue = LibRPM::DbiTagVal
  alias FileState = LibRPM::FileState
  alias FileAttrs = LibRPM::FileAttrs

  alias Sense = LibRPM::Sense
  alias TransactionFlags = LibRPM::TransFlags
  alias MireMode = LibRPM::MireMode
  alias ProblemType = LibRPM::ProblemType

  # Create a problem with RPM 4.9 or later calling convention
  def self.problem_create(type, pkg_nevr, key, alt_nevr, str, number)
    {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
      case type
      when ProblemType::REQUIRES, ProblemType::CONFLICT, ProblemType::OBSOLETES
        pkg_nevr, str, alt_nevr = alt_nevr, pkg_nevr, "  " + str
        number = (number == 0) ? 1 : 0
      end
      LibRPM.rpmProblemCreate(type, pkg_nevr, key, nil, str, alt_nevr, number)
    {% else %}
      LibRPM.rpmProblemCreate(type, pkg_nevr, key, alt_nevr, str, number)
    {% end %}
  end

  # Create a problem with RPM 4.8.x calling convention
  def self.problem_create(type, pkg_nevr, key, dir, file, alt_nevr, number)
    {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
      LibRPM.rpmProblemCreate(type, pkg_nevr, key, dir, file, alt_nevr, number)
    {% else %}
      str = dir || ""
      str += file if file
      case type
      when ProblemType::REQUIRES, ProblemType::CONFLICT, ProblemType::OBSOLETES
        str, alt_nevr, pkg_nevr = alt_nevr[2..-1], pkg_nevr, str
        number = (number != 0) ? 0 : 1
      end
      LibRPM.rpmProblemCreate(type, pkg_nevr, key, alt_nevr, str, number)
    {% end %}
  end

  # Return Tag Type for a Tag
  #
  # * Calls `rpmTagGetType()` for RPM 4.9 or later,
  # * Calls `rpmTagGetType()` and mask for RPM 4.8
  def self.tag_type(v) : TagType
    {% if compare_versions(PKGVERSION_COMP, "4.9.0") >= 0 %}
      LibRPM.rpmTagType(v)
    {% else %}
      m = LibRPM.rpmTagGetType(v)
      TagType.new((m & ~TagReturnType::MASK.value).to_i32)
    {% end %}
  end

  # Return Tag Return Type for a tag
  #
  # * Calls `rpmTagGetReturnType()` for RPM 4.9 or later,
  # * Calls `rpmTagGetType()` and mask for RPM 4.8
  def self.tag_get_return_type(v) : TagReturnType
    {% if compare_versions(PKGVERSION_COMP, "4.9.0") >= 0 %}
      LibRPM.rpmTagGetReturnType(v)
    {% else %}
      m = LibRPM.rpmTagGetType(v)
      TagReturnType.new(m & TagReturnType::MASK.value)
    {% end %}
  end

  # Add macro definitiion
  #
  # * Calls `rpmPushMacro()` for RPM 4.14 or later,
  # * Calls `addMacro()` for otherwise
  def self.push_macro(mc, n, o, b, level) : Int
    {% if compare_versions(PKGVERSION_COMP, "4.14.0") >= 0 %}
      LibRPM.rpmPushMacro(mc, n, o, b, level)
    {% else %}
      LibRPM.addMacro(mc, n, o, b, level)
    {% end %}
  end

  # Remove macro definition
  #
  # * Calls `rpmPopMacro()` for RPM 4.14 or later,
  # * Calls `delMacro()` for otherwise
  def self.pop_macro(mc, n) : Int
    {% if compare_versions(PKGVERSION_COMP, "4.14.0") >= 0 %}
      LibRPM.rpmPopMacro(mc, n)
    {% else %}
      LibRPM.delMacro(mc, n)
    {% end %}
  end
end
