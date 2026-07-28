#!/usr/bin/env python3
"""Generate MakeupChat.xcodeproj for the SwiftUI iOS app."""

import os
import uuid

ROOT = "/Users/xlzj/figma/makeup-chat-screen/ios"
PROJECT_NAME = "MakeupChat"
BUNDLE_ID = "com.makeup.chat"

SOURCES = [
    "MakeupChat/MakeupChatApp.swift",
    "MakeupChat/ContentView.swift",
    "MakeupChat/Models/ChatMessage.swift",
    "MakeupChat/Database/Schema.swift",
    "MakeupChat/Database/DatabaseManager.swift",
    "MakeupChat/Database/DatabaseSeeder.swift",
    "MakeupChat/Repositories/UserRepository.swift",
    "MakeupChat/Repositories/ChatRepository.swift",
    "MakeupChat/Repositories/MakeupCatalogRepository.swift",
    "MakeupChat/Services/ChatSessionService.swift",
    "MakeupChat/ViewModels/ChatViewModel.swift",
    "MakeupChat/Components/GradientBackgroundView.swift",
    "MakeupChat/Components/ProfileHeaderView.swift",
    "MakeupChat/Components/TipBarView.swift",
    "MakeupChat/Components/ChatBubbleView.swift",
    "MakeupChat/Components/MakeupInputBar.swift",
    "MakeupChat/Components/SuggestionChipsView.swift",
    "MakeupChat/Views/ChatConversationView.swift",
    "MakeupChat/Views/NegativeOneScreen01View.swift",
    "MakeupChat/Views/NegativeOneScreen02View.swift",
]

GROUP_PREFIXES = [
    ("Models", "MakeupChat/Models/"),
    ("Database", "MakeupChat/Database/"),
    ("Repositories", "MakeupChat/Repositories/"),
    ("Services", "MakeupChat/Services/"),
    ("ViewModels", "MakeupChat/ViewModels/"),
    ("Components", "MakeupChat/Components/"),
    ("Views", "MakeupChat/Views/"),
]

ASSETS = "MakeupChat/Resources/Assets.xcassets"


def uid():
    return uuid.uuid4().hex[:24].upper()


# Fixed IDs for stability
PROJECT_ID = "A10000000000000000000001"
TARGET_ID = "A10000000000000000000002"
SOURCES_PHASE = "A10000000000000000000003"
RESOURCES_PHASE = "A10000000000000000000004"
BUILD_CONFIG_LIST_PROJ = "A10000000000000000000005"
BUILD_CONFIG_LIST_TARGET = "A10000000000000000000006"
DEBUG_CONFIG_PROJ = "A10000000000000000000007"
RELEASE_CONFIG_PROJ = "A10000000000000000000008"
DEBUG_CONFIG_TARGET = "A10000000000000000000009"
RELEASE_CONFIG_TARGET = "A1000000000000000000000A"
MAIN_GROUP = "A1000000000000000000000B"
PRODUCTS_GROUP = "A1000000000000000000000C"
APP_GROUP = "A1000000000000000000000D"
PRODUCT_REF = "A1000000000000000000000E"

file_refs = {}
build_files_src = []
build_files_res = []

for src in SOURCES:
    fid = uid()
    bid = uid()
    file_refs[src] = fid
    build_files_src.append((bid, fid, src))

assets_fid = uid()
assets_bid = uid()
file_refs[ASSETS] = assets_fid
build_files_res.append((assets_bid, assets_fid, ASSETS))

# Groups
group_ids = {name: uid() for name, _ in GROUP_PREFIXES}
resources_group = uid()

pbx = []

pbx.append("// !$*UTF8*$!")
pbx.append("{")
pbx.append("\tarchiveVersion = 1;")
pbx.append("\tclasses = {};")
pbx.append("\tobjectVersion = 56;")
pbx.append("\tobjects = {")

# PBXBuildFile
pbx.append("\n/* Begin PBXBuildFile section */")
for bid, fid, path in build_files_src:
    pbx.append(f"\t\t{bid} /* {os.path.basename(path)} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {os.path.basename(path)} */; }};")
for bid, fid, path in build_files_res:
    pbx.append(f"\t\t{bid} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {fid} /* Assets.xcassets */; }};")
pbx.append("/* End PBXBuildFile section */\n")

# PBXFileReference
pbx.append("/* Begin PBXFileReference section */")
pbx.append(f"\t\t{PRODUCT_REF} /* {PROJECT_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {PROJECT_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
for path, fid in file_refs.items():
    name = os.path.basename(path)
    if path.endswith(".xcassets"):
        pbx.append(f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = {name}; sourceTree = \"<group>\"; }};")
    else:
        pbx.append(f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};")
pbx.append("/* End PBXFileReference section */\n")

# PBXFrameworksBuildPhase
pbx.append("/* Begin PBXFrameworksBuildPhase section */")
pbx.append(f"\t\t{uid()} /* Frameworks */ = {{")
pbx.append("\t\t\tisa = PBXFrameworksBuildPhase;")
pbx.append("\t\t\tbuildActionMask = 2147483647;")
pbx.append("\t\t\tfiles = (")
pbx.append("\t\t\t);")
pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
pbx.append("\t\t};")
pbx.append("/* End PBXFrameworksBuildPhase section */\n")

# PBXGroup
pbx.append("/* Begin PBXGroup section */")
pbx.append(f"\t\t{MAIN_GROUP} = {{")
pbx.append("\t\t\tisa = PBXGroup;")
pbx.append("\t\t\tchildren = (")
pbx.append(f"\t\t\t\t{APP_GROUP} /* MakeupChat */,")
pbx.append(f"\t\t\t\t{PRODUCTS_GROUP} /* Products */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\tsourceTree = \"<group>\";")
pbx.append("\t\t};")

pbx.append(f"\t\t{PRODUCTS_GROUP} /* Products */ = {{")
pbx.append("\t\t\tisa = PBXGroup;")
pbx.append("\t\t\tchildren = (")
pbx.append(f"\t\t\t\t{PRODUCT_REF} /* {PROJECT_NAME}.app */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\tname = Products;")
pbx.append("\t\t\tsourceTree = \"<group>\";")
pbx.append("\t\t};")

# App group children
nested_prefixes = {prefix for _, prefix in GROUP_PREFIXES}
app_children = []
for path in SOURCES:
    if any(path.startswith(prefix) for prefix in nested_prefixes):
        continue
    app_children.append(file_refs[path])

pbx.append(f"\t\t{APP_GROUP} /* MakeupChat */ = {{")
pbx.append("\t\t\tisa = PBXGroup;")
pbx.append("\t\t\tchildren = (")
for cid in app_children:
    for path, fid in file_refs.items():
        if fid == cid and not path.endswith(".xcassets"):
            pbx.append(f"\t\t\t\t{fid} /* {os.path.basename(path)} */,")
for group_name, _ in GROUP_PREFIXES:
    pbx.append(f"\t\t\t\t{group_ids[group_name]} /* {group_name} */,")
pbx.append(f"\t\t\t\t{resources_group} /* Resources */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\tpath = MakeupChat;")
pbx.append("\t\t\tsourceTree = \"<group>\";")
pbx.append("\t\t};")

for group_name, prefix in GROUP_PREFIXES:
    group_id = group_ids[group_name]
    pbx.append(f"\t\t{group_id} /* {group_name} */ = {{")
    pbx.append("\t\t\tisa = PBXGroup;")
    pbx.append("\t\t\tchildren = (")
    for path, fid in file_refs.items():
        if path.startswith(prefix):
            pbx.append(f"\t\t\t\t{fid} /* {os.path.basename(path)} */,")
    pbx.append("\t\t\t);")
    pbx.append(f"\t\t\tpath = {group_name};")
    pbx.append("\t\t\tsourceTree = \"<group>\";")
    pbx.append("\t\t};")

pbx.append(f"\t\t{resources_group} /* Resources */ = {{")
pbx.append("\t\t\tisa = PBXGroup;")
pbx.append("\t\t\tchildren = (")
pbx.append(f"\t\t\t\t{assets_fid} /* Assets.xcassets */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\tpath = Resources;")
pbx.append("\t\t\tsourceTree = \"<group>\";")
pbx.append("\t\t};")
pbx.append("/* End PBXGroup section */\n")

# PBXNativeTarget
pbx.append("/* Begin PBXNativeTarget section */")
pbx.append(f"\t\t{TARGET_ID} /* {PROJECT_NAME} */ = {{")
pbx.append("\t\t\tisa = PBXNativeTarget;")
pbx.append(f"\t\t\tbuildConfigurationList = {BUILD_CONFIG_LIST_TARGET} /* Build configuration list for PBXNativeTarget \"{PROJECT_NAME}\" */;")
pbx.append("\t\t\tbuildPhases = (")
pbx.append(f"\t\t\t\t{SOURCES_PHASE} /* Sources */,")
pbx.append(f"\t\t\t\t{RESOURCES_PHASE} /* Resources */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\tbuildRules = (")
pbx.append("\t\t\t);")
pbx.append("\t\t\tdependencies = (")
pbx.append("\t\t\t);")
pbx.append(f"\t\t\tname = {PROJECT_NAME};")
pbx.append(f"\t\t\tproductName = {PROJECT_NAME};")
pbx.append(f"\t\t\tproductReference = {PRODUCT_REF} /* {PROJECT_NAME}.app */;")
pbx.append("\t\t\tproductType = \"com.apple.product-type.application\";")
pbx.append("\t\t};")
pbx.append("/* End PBXNativeTarget section */\n")

# PBXProject
pbx.append("/* Begin PBXProject section */")
pbx.append(f"\t\t{PROJECT_ID} /* Project object */ = {{")
pbx.append("\t\t\tisa = PBXProject;")
pbx.append("\t\t\tattributes = {")
pbx.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
pbx.append("\t\t\t\tLastSwiftUpdateCheck = 2600;")
pbx.append("\t\t\t\tLastUpgradeCheck = 2600;")
pbx.append("\t\t\t\tTargetAttributes = {")
pbx.append(f"\t\t\t\t\t{TARGET_ID} = {{")
pbx.append("\t\t\t\t\t\tCreatedOnToolsVersion = 26.0;")
pbx.append("\t\t\t\t\t};")
pbx.append("\t\t\t\t};")
pbx.append("\t\t\t};")
pbx.append(f"\t\t\tbuildConfigurationList = {BUILD_CONFIG_LIST_PROJ} /* Build configuration list for PBXProject \"{PROJECT_NAME}\" */;")
pbx.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
pbx.append("\t\t\tdevelopmentRegion = \"zh-Hans\";")
pbx.append("\t\t\thasScannedForEncodings = 0;")
pbx.append("\t\t\tknownRegions = (")
pbx.append("\t\t\t\ten,")
pbx.append("\t\t\t\t\"zh-Hans\",")
pbx.append("\t\t\t\tBase,")
pbx.append("\t\t\t);")
pbx.append(f"\t\t\tmainGroup = {MAIN_GROUP};")
pbx.append(f"\t\t\tproductRefGroup = {PRODUCTS_GROUP} /* Products */;")
pbx.append("\t\t\tprojectDirPath = \"\";")
pbx.append("\t\t\tprojectRoot = \"\";")
pbx.append("\t\t\ttargets = (")
pbx.append(f"\t\t\t\t{TARGET_ID} /* {PROJECT_NAME} */,")
pbx.append("\t\t\t);")
pbx.append("\t\t};")
pbx.append("/* End PBXProject section */\n")

# PBXResourcesBuildPhase
pbx.append("/* Begin PBXResourcesBuildPhase section */")
pbx.append(f"\t\t{RESOURCES_PHASE} /* Resources */ = {{")
pbx.append("\t\t\tisa = PBXResourcesBuildPhase;")
pbx.append("\t\t\tbuildActionMask = 2147483647;")
pbx.append("\t\t\tfiles = (")
for bid, fid, path in build_files_res:
    pbx.append(f"\t\t\t\t{bid} /* Assets.xcassets in Resources */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
pbx.append("\t\t};")
pbx.append("/* End PBXResourcesBuildPhase section */\n")

# PBXSourcesBuildPhase
pbx.append("/* Begin PBXSourcesBuildPhase section */")
pbx.append(f"\t\t{SOURCES_PHASE} /* Sources */ = {{")
pbx.append("\t\t\tisa = PBXSourcesBuildPhase;")
pbx.append("\t\t\tbuildActionMask = 2147483647;")
pbx.append("\t\t\tfiles = (")
for bid, fid, path in build_files_src:
    pbx.append(f"\t\t\t\t{bid} /* {os.path.basename(path)} in Sources */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
pbx.append("\t\t};")
pbx.append("/* End PBXSourcesBuildPhase section */\n")

# XCBuildConfiguration
common_swift = [
    "\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
    "\t\t\t\tCODE_SIGN_STYLE = Automatic;",
    f"\t\t\t\tCURRENT_PROJECT_VERSION = 1;",
    f"\t\t\t\tDEVELOPMENT_TEAM = \"\";",
    "\t\t\t\tENABLE_PREVIEWS = YES;",
    f"\t\t\t\tGENERATE_INFOPLIST_FILE = YES;",
    "\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;",
    "\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;",
    "\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;",
    "\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;",
    "\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;",
    f"\t\t\t\tMARKETING_VERSION = 1.0;",
    "\t\t\t\tOTHER_LDFLAGS = \"-lsqlite3\";",
    f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};",
    f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";",
    "\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;",
    "\t\t\t\tSWIFT_VERSION = 5.0;",
    "\t\t\t\tTARGETED_DEVICE_FAMILY = 1;",
]

pbx.append("/* Begin XCBuildConfiguration section */")
for cfg_id, name, is_target in [
    (DEBUG_CONFIG_PROJ, "Debug", False),
    (RELEASE_CONFIG_PROJ, "Release", False),
    (DEBUG_CONFIG_TARGET, "Debug", True),
    (RELEASE_CONFIG_TARGET, "Release", True),
]:
    pbx.append(f"\t\t{cfg_id} /* {name} */ = {{")
    pbx.append("\t\t\tisa = XCBuildConfiguration;")
    if is_target:
        pbx.append(f"\t\t\tbuildSettings = {{")
        for line in common_swift:
            pbx.append(line)
        pbx.append("\t\t\t};")
    else:
        pbx.append("\t\t\tbuildSettings = {")
        pbx.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
        pbx.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
        pbx.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
        pbx.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
        pbx.append("\t\t\t\tENABLE_TESTABILITY = YES;" if name == "Debug" else "\t\t\t\tENABLE_NS_ASSERTIONS = NO;")
        pbx.append("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;" if name == "Debug" else "\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
        pbx.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
        pbx.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;" if name == "Debug" else "\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;")
        pbx.append(f"\t\t\t\tONLY_ACTIVE_ARCH = {'YES' if name == 'Debug' else 'NO'};")
        pbx.append(f"\t\t\t\tSDKROOT = iphoneos;")
        pbx.append(f"\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";" if name == "Debug" else "\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
        pbx.append(f"\t\t\t\tSWIFT_VERSION = 5.0;")
        pbx.append("\t\t\t};")
    pbx.append(f"\t\t\tname = {name};")
    pbx.append("\t\t};")

pbx.append("/* End XCBuildConfiguration section */\n")

# XCConfigurationList
pbx.append("/* Begin XCConfigurationList section */")
for list_id, name, cfgs in [
    (BUILD_CONFIG_LIST_PROJ, PROJECT_NAME, [(DEBUG_CONFIG_PROJ, "Debug"), (RELEASE_CONFIG_PROJ, "Release")]),
    (BUILD_CONFIG_LIST_TARGET, PROJECT_NAME, [(DEBUG_CONFIG_TARGET, "Debug"), (RELEASE_CONFIG_TARGET, "Release")]),
]:
    pbx.append(f"\t\t{list_id} /* Build configuration list for PBXProject \"{name}\" */ = {{")
    pbx.append("\t\t\tisa = XCConfigurationList;")
    pbx.append("\t\t\tbuildConfigurations = (")
    for cid, cname in cfgs:
        pbx.append(f"\t\t\t\t{cid} /* {cname} */,")
    pbx.append("\t\t\t);")
    pbx.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    pbx.append("\t\t\tdefaultConfigurationName = Release;")
    pbx.append("\t\t};")
pbx.append("/* End XCConfigurationList section */")

pbx.append("\t};")
pbx.append(f"\trootObject = {PROJECT_ID} /* Project object */;")
pbx.append("}")

proj_dir = os.path.join(ROOT, f"{PROJECT_NAME}.xcodeproj")
os.makedirs(proj_dir, exist_ok=True)
with open(os.path.join(proj_dir, "project.pbxproj"), "w") as f:
    f.write("\n".join(pbx))

print(f"Generated {proj_dir}/project.pbxproj")
