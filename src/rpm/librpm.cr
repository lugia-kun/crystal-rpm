module RPM
  # :nodoc:
  macro define_version(const, version)
    {{const}} = {{version}}
  end

  # :nodoc:
  macro define_version_constants(version)
    # The version of librpm which is used at compiled time.
    PKGVERSION = {{version}}

    {% semver = version.split("-") %}
    {% splitted = semver[0].split(".") %}

    # Major version part of `PKGVERSION`
    PKGVERSION_MAJOR = {{splitted[0].to_i}}

    # Minor version part of `PKGVERSION`
    PKGVERSION_MINOR = {{splitted[1].to_i}}

    # Patch version part of `PKGVERSION`
    PKGVERSION_PATCH = {{splitted[2].to_i}}

    # If `PKGVERSION` has 4 parts, `PKGVERSION_EXTRA` contains the fourth part.
    # For example, if the version is `4.14.2.1`, `PKGVERSION_EXTRA` will be
    # set to `1`.
    #
    # `PKGVERSION_EXTRA` will be 0 if fourth part does not exist.
    PKGVERSION_EXTRA = {{splitted.size > 3 ? splitted[3].to_i : 0}}
  end

  define_version_constants({{`pkg-config rpm --modversion`.chomp.stringify}})

  # :nodoc:
  macro define_3_parts_version(maj, min, pat)
    # Comparable version of `PKGVERSION` by `compare_versions()`.
    define_version(PKGVERSION_COMP, {{[maj, min, pat].join(".")}})
  end

  define_3_parts_version({{PKGVERSION_MAJOR}}, {{PKGVERSION_MINOR}}, {{PKGVERSION_PATCH}})

  # Definition of interface with librpm.
  #
  @[Link(ldflags: "`pkg-config rpm --libs` -lrpmbuild")]
  lib LibRPM
    # Dev note: Do not add a version restriction fence (i.e.
    #           `{% if compare_versions() %} ... {% end %}`) unless
    #           there are interface incompatibilities,
    #           such as parameter type or number, return type,
    #           type definition, or enum value changed.
    #
    #           Changes like which a function or an enum value is
    #           introduced or removed does not classify to an interface
    #           incompatibility.

    # ## Internal types
    alias Int = LibC::Int
    alias UInt = LibC::UInt
    alias SizeT = LibC::SizeT

    # BUFSIZ is in stdio.h, the value is for glibc-2.28 on x86_64 linux
    BUFSIZ = 8192

    # Spec structure definition in RPM 4.8.
    struct SpecLines
      sl_lines : Pointer(UInt8*)
      sl_nalloc : Int
      ls_nlines : Int
    end

    struct SpecTags
      st_t : Pointer(Void) # Not supported
      st_nalloc : Int
      st_ntags : Int
    end

    struct Source_s
      full_source : Pointer(UInt8)
      source : Pointer(UInt8)
      flags : Int
      num : UInt32
      next : Pointer(Source_s)
    end

    struct Package_s
      header : Header
      ds : DependencySet
      cpio_list : FileInfo
      icon : Pointer(Source_s)
      auto_req : Int
      auto_prov : Int
      pre_in_file : Pointer(UInt8)
      post_in_file : Pointer(UInt8)
      pre_un_file : Pointer(UInt8)
      post_un_file : Pointer(UInt8)
      pre_trans_file : Pointer(UInt8)
      post_trans_file : Pointer(UInt8)
      verify_file : Pointer(UInt8)
      special_doc : StringBuf
      special_doc_dir : Pointer(UInt8)
      trigger_files : Pointer(Void) # not supported
      file_file : StringBuf
      file_list : StringBuf
      next : Pointer(Package_s)
    end

    struct Spec_s
      spec_file : Pointer(UInt8)
      buildroot : Pointer(UInt8)
      build_subdir : Pointer(UInt8)
      rootdir : Pointer(UInt8)
      sl : Pointer(SpecLines)
      st : Pointer(SpecTags)
      fileStack : Pointer(Void) # Not supported
      {% begin %}
      lbuf : {
        {% for i in 0...(10*BUFSIZ) %}
          UInt8,
        {% end %}
      }
      {% end %}
      lbuf_ptr : Pointer(UInt8)
      nextpeec_c : UInt8
      nextline : Pointer(UInt8)
      line : Pointer(UInt8)
      line_num : Int
      read_stack : Pointer(Void) # Not supported
      build_restrictions : Header
      ba_specs : Spec
      ba_names : Pointer(UInt8*)
      ba_count : Int
      recursing : Int
      force : Int
      anyarch : Int
      pass_phrase : Pointer(UInt8*)
      time_check : Int
      cookie : Pointer(UInt8)
      sources : Pointer(Source_s)
      num_sources : Int
      no_source : Int
      source_rpm_name : Pointer(UInt8)
      source_pkg_id : Pointer(UInt8)
      source_header : Header
      source_cpio_list : FileInfo
      macros : MacroContext
      prep : StringBuf
      build : StringBuf
      install : StringBuf
      check : StringBuf
      clean : StringBuf
      packages : Pointer(Package_s)
    end

    struct BuildArguments_s
      {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
        qva : QueryFlags
        build_amount : Int
        build_root : Pointer(UInt8)
        targets : Pointer(UInt8)
        pass_phrase : Pointer(UInt8)
        cookie : Pointer(UInt8)
        force : Int
        no_build : Int
        no_deps : Int
        no_lang : Int
        short_circuit : Int
        sign : Int
        build_mode : UInt8
        build_char : UInt8
      {% else %}
        pkg_flags : BuildPkgFlags
        build_amount : BuildFlags
        build_root : Pointer(UInt8)
        cookie : Pointer(UInt8)
      {% end %}
      rootdir : Pointer(UInt8)
    end

    alias Count = UInt32
    alias RPMFlags = UInt32
    alias TagVal = Int32
    alias DbiTagVal = TagVal
    alias Loff = UInt64

    type Header = Pointer(Void)
    type HeaderIterator = Pointer(Void)
    alias Transaction = Pointer(Void)
    type TransactionElement = Pointer(Void)
    type TransactionIterator = Pointer(Void)
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
    {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
      type Spec = Pointer(Spec_s)
    {% else %}
      type Spec = Pointer(Void)
    {% end %}
    type StringBuf = Pointer(Void)
    type FileInfo = Pointer(Void)
    type SpecPkgIter = Pointer(Void)
    type SpecPkg = Pointer(Void)
    type SpecSrcIter = Pointer(Void)
    type SpecSrc = Pointer(Void)
    type BuildArguments = Pointer(BuildArguments_s)

    alias RPMDs = DependencySet
    alias RPMPs = ProblemSet
    alias RPMPsi = ProblemSetIterator
    alias RPMTd = TagData
    alias RPMTs = Transaction
    alias RPMTe = TransactionElement
    alias RPMTsi = TransactionIterator
    alias RPMDb = Database
    alias RPMFi = FileInfo
    alias RPMDbMatchIterator = DatabaseMatchIterator

    alias ErrorMsg = Pointer(UInt8)

    enum RC
      OK; NOTFOUND; FAIL; NOTTRUSTED; NOKEY
    end

    enum QueryFlags : RPMFlags
      FOR_DEFAULT   = 0
      MD5           = (1_u32 << 0)
      FILEDIGEST    = (1_u32 << 0)
      SIZE          = (1_u32 << 1)
      LINKTO        = (1_u32 << 2)
      USER          = (1_u32 << 3)
      GROUP         = (1_u32 << 4)
      MTIME         = (1_u32 << 5)
      MODE          = (1_u32 << 6)
      RDEV          = (1_u32 << 7)
      CONTEXTS      = (1_u32 << 15)
      FILES         = (1_u32 << 16)
      DEPS          = (1_u32 << 17)
      SCRIPT        = (1_u32 << 18)
      DIGEST        = (1_u32 << 19)
      SIGNATURE     = (1_u32 << 20)
      PATCHES       = (1_u32 << 21)
      HDRCHK        = (1_u32 << 22)
      FOR_LIST      = (1_u32 << 23)
      FOR_STATE     = (1_u32 << 24)
      FOR_DOCS      = (1_u32 << 25)
      FOR_CONFIG    = (1_u32 << 26)
      FOR_DUMPFILES = (1_u32 << 27)
      FOR_LICENSE   = (1_u32 << 28)
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
      SCRIPT_START       = (1_u32 << 16)
      SCRIPT_STOP        = (1_u32 << 17)
      INST_STOP          = (1_u32 << 18)
      ELEM_PROGRESS      = (1_u32 << 19)
      VERIFY_PROGRESS    = (1_u32 << 20)
      VERIFY_START       = (1_u32 << 21)
      VERIFY_STOP        = (1_u32 << 22)
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
    fun rpmdbFreeIterator(RPMDbMatchIterator) : RPMDbMatchIterator

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
      META          = (1_u32 << 29)
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
      ARTIFACT  = (1_u32 << 12)
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
      # FILESIGNATURES = SigBase + 18
      # FILESIGNATURELENGTH = SigBase + 19

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
      AutoInstalled               = 5094
      Identity                    = 5095
      ModularityLabel             = 5096
      PayloadDigestAlt            = 5097

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
      NULL         = 0
      CHAR         = 1
      INT8         = 2
      INT16        = 3
      INT32        = 4
      INT64        = 5
      STRING       = 6
      BIN          = 7
      STRING_ARRAY = 8
      I18NSTRING   = 9
    end

    enum SubTagType
      REGION    = -10
      BIN_ARRAY = -11
      XREF      = -12
    end

    enum TagClass
      NULL; NUMERIC; STRING; BINARY
    end

    fun rpmTagGetName(TagVal) : Pointer(UInt8)
    fun rpmTagGetNames(TagData, Int) : Int
    fun rpmTagGetClass(TagVal) : TagClass
    fun rpmTagGetType(TagVal) : RPMFlags

    # These two functions are added on 4.9.0
    # Use RPM#tag_type and RPM#tag_get_return_type instead.
    fun rpmTagGetTagType(TagVal) : TagType
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
    fun headerGetInstance(Header) : UInt

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

    {% if compare_versions(PKGVERSION_COMP, "4.14.0") < 0 %}
      fun addMacro(MacroContext, UInt8*, UInt8*, UInt8*, Int) : Int
      fun delMacro(MacroContext, UInt8*) : Int
    {% else %}
      fun rpmPushMacro(MacroContext, UInt8*, UInt8*, UInt8*, Int) : Int
      fun rpmPopMacro(MacroContext, UInt8*) : Int
    {% end %}

    fun rpmExpand(UInt8*, ...) : Pointer(UInt8)
    {% if compare_versions(PKGVERSION_COMP, "4.14.0") < 0 %}
      fun expandMacros(Void*, MacroContext, UInt8*, Int) : Int
    {% end %}
    {% if compare_versions(PKGVERSION_COMP, "4.13.0") >= 0 %}
      fun rpmExpandMacros(MacroContext, UInt8*, UInt8**, Int) : Int
    {% end %}

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
      VERIFY
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
    fun rpmProblemGetPkgNEVR(Problem) : Pointer(UInt8)
    fun rpmProblemGetAltNEVR(Problem) : Pointer(UInt8)
    fun rpmProblemGetDiskNeed(Problem) : Loff

    # ## Problem Set APIs.

    fun rpmpsInitIterator(ProblemSet) : ProblemSetIterator
    fun rpmpsNextIterator(ProblemSetIterator) : Int
    fun rpmpsGetProblem(ProblemSetIterator) : Problem
    fun rpmpsFree(ProblemSet) : ProblemSet
    fun rpmpsFreeIterator(ProblemSetIterator) : ProblemSetIterator
    fun rpmpsNumProblems(ProblemSet) : Int

    # ## TagData APIs.

    @[Flags]
    enum TagDataFlags : UInt32
      NONE       = 0
      ALLOCED    = (1 << 0)
      PTRALLOCED = (1 << 1)
      IMMUTABLE  = (1 << 2)
      ARGV       = (1 << 3)
      INVALID    = (1 << 4)
    end

    fun rpmtdNew : TagData
    fun rpmtdFree(TagData) : TagData
    fun rpmtdReset(TagData) : TagData
    fun rpmtdFreeData(TagData) : Void
    fun rpmtdCount(TagData) : UInt32
    fun rpmtdTag(TagData) : TagVal
    fun rpmtdType(TagData) : TagType
    fun rpmtdSetIndex(TagData, Int) : Int
    fun rpmtdGetIndex(TagData) : Int
    fun rpmtdGetFlags(TagData) : TagDataFlags

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

    fun rpmtdSetTag(TagData, TagVal) : Int
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
      NOARTIFACTS     = (1_u32 << 29)
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

    fun rpmtsSetNotifyCallback(Transaction, CallbackFunction, Void*) : Int

    fun rpmtsRootDir(Transaction) : Pointer(UInt8)
    fun rpmtsSetRootDir(Transaction, UInt8*) : Int

    fun rpmtsGetRdb(Transaction) : Database

    fun rpmtsFlags(Transaction) : TransFlags
    fun rpmtsSetFlags(Transaction, TransFlags) : TransFlags

    fun rpmtsCreate : Transaction
    fun rpmtsAddInstallElement(Transaction, Header, FnpyKey, Int, Relocation) : Int
    fun rpmtsAddEraseElement(Transaction, Header, Int) : Int
    fun rpmtsEmpty(Transaction) : Void

    # ## Transaction Element API
    enum ElementType
      ADDED   = (1 << 0)
      REMOVED = (1 << 1)
      RPMDB   = (1 << 2)
    end

    {% begin %}
    @[Flags]
    enum ElementTypes : RPMFlags
      ANY = 0   # For using with `rpmtsiNext`
      {% for el in ElementType.constants %}
        {{el}} = ElementType::{{el}}
      {% end %}
    end
    {% end %}

    fun rpmteHeader(TransactionElement) : Header
    fun rpmteSetHeader(TransactionElement, Header) : Header
    fun rpmteType(TransactionElement) : ElementType
    fun rpmteN(TransactionElement) : Pointer(UInt8)
    fun rpmteE(TransactionElement) : Pointer(UInt8)
    fun rpmteV(TransactionElement) : Pointer(UInt8)
    fun rpmteR(TransactionElement) : Pointer(UInt8)
    fun rpmteA(TransactionElement) : Pointer(UInt8)
    fun rpmteO(TransactionElement) : Pointer(UInt8)
    fun rpmteIsSource(TransactionElement) : Int
    fun rpmtePkgFileSize(TransactionElement) : Loff
    fun rpmteParent(TransactionElement) : TransactionElement
    fun rpmteSetParent(TransactionElement, TransactionElement) : TransactionElement
    fun rpmteProblems(TransactionElement) : ProblemSet
    fun rpmteCleanProblems(TransactionElement) : Void
    fun rpmteCleanDS(TransactionElement) : Void
    fun rpmteSetDependsOn(TransactionElement, TransactionElement) : Void
    fun rpmteDependsOn(TransactionElement) : TransactionElement
    fun rpmteDBOffset(TransactionElement) : Int
    fun rpmteEVR(TransactionElement) : Pointer(UInt8)
    fun rpmteNEVR(TransactionElement) : Pointer(UInt8)
    fun rpmteNEVRA(TransactionElement) : Pointer(UInt8)
    fun rpmteKey(TransactionElement) : FnpyKey
    fun rpmteFailed(TransactionElement) : Int
    fun rpmteDS(TransactionElement, TagValue) : DependencySet
    # fun rpmteFiles(TransactionElement) : FileInfoSet
    # fun rpmteFI(TransactionElement) : FileInfoSetIterator

    fun rpmtsiInit(Transaction) : TransactionIterator
    fun rpmtsiFree(TransactionIterator) : TransactionIterator
    fun rpmtsiNext(TransactionIterator, ElementTypes) : TransactionElement

    # ## RC
    fun rpmReadConfigFiles(UInt8*, UInt8*) : Int

    # ## Spec
    @[Flags]
    enum BuildPkgFlags : RPMFlags
      NONE        = 0
      NODIRTOKENS = (1_u32 << 0)
    end

    @[Flags]
    enum BuildFlags : RPMFlags
      NONE               = 0
      PREP               = (1_u32 << 0)
      BUILD              = (1_u32 << 1)
      INSTALL            = (1_u32 << 2)
      CHECK              = (1_u32 << 3)
      CLEAN              = (1_u32 << 4)
      FILECHECK          = (1_u32 << 5)
      PACKAGESOURCE      = (1_u32 << 6)
      PACKAGEBINARY      = (1_u32 << 7)
      RMSOURCE           = (1_u32 << 8)
      RMBUILD            = (1_u32 << 9)
      STRINGBUF          = (1_u32 << 10)
      RMSPEC             = (1_u32 << 11)
      FILE_FILE          = (1_u32 << 16)
      FILE_LIST          = (1_u32 << 17)
      POLICY             = (1_u32 << 18)
      CHECKBUILDREQUIRES = (1_u32 << 19)
      BUILDREQUIRES      = (1_u32 << 20)
      DUMPBUILDREQUIRES  = (1_u32 << 21)
      NOBUILD            = (1_u32 << 31)
    end

    # RPM 4.8 APIs.
    fun parseSpec(Transaction, UInt8*, UInt8*, UInt8*, Int, UInt8*, UInt8*, Int, Int) : Int
    fun rpmtsSpec(Transaction) : Spec
    # fun build(Transaction, UInt8*, BuildArguments, UInt8*) : Int
    fun buildSpec(Transaction, Spec, Int, Int) : RC
    fun freeSpec(Spec)

    # RPM 4.9 APIs.
    @[Flags]
    enum SourceFlags : RPMFlags
      ISSOURCE = (1_u32 << 0)
      ISPATCH  = (1_u32 << 1)
      ISICON   = (1_u32 << 2)
      ISNO     = (1_u32 << 3)
    end

    @[Flags]
    enum SpecFlags : RPMFlags
      NONE    = 0
      ANYARCH = (1_u32 << 0)
      FORCE   = (1_u32 << 1)
      NOLANG  = (1_u32 << 2)
      NOUTF8  = (1_u32 << 3)
    end

    fun rpmSpecParse(UInt8*, SpecFlags, UInt8*) : Spec
    fun rpmSpecFree(Spec) : Spec
    fun rpmSpecSourceHeader(Spec) : Header
    fun rpmSpecPkgIterInit(Spec) : SpecPkgIter
    fun rpmSpecPkgIterNext(SpecPkgIter) : SpecPkg
    fun rpmSpecPkgFree(SpecPkgIter) : SpecPkgIter
    fun rpmSpecPkgIterFree(SpecPkgIter) : SpecPkgIter
    fun rpmSpecPkgHeader(SpecPkg) : Header
    fun rpmSpecSrcIterInit(Spec) : SpecSrcIter
    fun rpmSpecSrcIterNext(SpecSrcIter) : SpecSrc
    fun rpmSpecSrcFree(SpecSrcIter) : SpecSrcIter
    fun rpmSpecSrcIterFree(SpecSrcIter) : SpecSrcIter
    fun rpmSpecSrcFlags(SpecSrc) : SourceFlags
    fun rpmSpecSrcNum(SpecSrc) : Int
    fun rpmSpecSrcFilename(SpecSrc) : Pointer(UInt8)

    {% if compare_versions(PKGVERSION_COMP, "4.15.0") >= 0 %}
      fun rpmSpecBuild(Transaction, Spec, BuildArguments) : Int
    {% else %}
      fun rpmSpecBuild(Spec, BuildArguments) : RC
    {% end %}
  end # LibRPM

  # Exposed Types

  alias Tag = LibRPM::Tag
  alias TagValue = LibRPM::TagVal
  alias TagType = LibRPM::TagType
  alias TagReturnType = LibRPM::TagReturnType
  alias DbiTag = LibRPM::DbiTag
  alias DbiTagValue = LibRPM::DbiTagVal
  alias HeaderGetFlags = LibRPM::HeaderGetFlags
  alias HeaderPutFlags = LibRPM::HeaderPutFlags
  alias FileState = LibRPM::FileState
  alias FileAttrs = LibRPM::FileAttrs
  alias CallbackType = LibRPM::CallbackType

  alias TagDataFlags = LibRPM::TagDataFlags
  alias TagDataFormat = LibRPM::TagDataFormat

  alias Sense = LibRPM::Sense
  alias TransactionFlags = LibRPM::TransFlags
  alias MireMode = LibRPM::MireMode
  alias ProblemType = LibRPM::ProblemType

  alias ElementType = LibRPM::ElementType
  alias ElementTypes = LibRPM::ElementTypes

  alias BuildPkgFlags = LibRPM::BuildPkgFlags
  alias BuildFlags = LibRPM::BuildFlags

  # Return TagType in the TagData pointer.
  #
  # * Returns the value returned by `rpmtdType` as-is for RPM 4.9 or
  #   later.
  # * Returns the value filtered out return type from returned value
  #   of `rpmtdType` for RPM 4.8.
  def self.rpmtd_type(ptr) : TagType
    {% if compare_versions(PKGVERSION_COMP, "4.9.0") >= 0 %}
      LibRPM.rpmtdType(ptr)
    {% else %}
      # `rpmtdFrom*` functions filters out return type from
      # `rpmGetTagType` function for setting `type` member of
      # `rpmtd`, but some functions also filters out return type
      # from the returned value of `rpmtdType`. So we also filters
      # out the return type.
      m = LibRPM.rpmtdType(ptr).value
      TagType.new((m & ~TagReturnType::MASK.value).to_i32)
    {% end %}
  end

  # Return Tag Type for a Tag
  #
  # * Calls `rpmTagGetTagType()` for RPM 4.9 or later,
  # * Calls `rpmTagGetType()` and mask for RPM 4.8
  def self.tag_type(v) : TagType
    {% if compare_versions(PKGVERSION_COMP, "4.9.0") >= 0 %}
      LibRPM.rpmTagGetTagType(v)
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
