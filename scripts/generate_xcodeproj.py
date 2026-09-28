#!/usr/bin/env python3
"""Generate LifeRPG.xcodeproj without XcodeGen/Homebrew."""

from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT_DIR = ROOT / "LifeRPG.xcodeproj"


def uid(*parts: str) -> str:
    return hashlib.md5("::".join(parts).encode()).hexdigest()[:24].upper()


def collect_files(relative_dir: str, suffix: str) -> list[str]:
    base = ROOT / relative_dir
    files = sorted(
        p.relative_to(ROOT).as_posix()
        for p in base.rglob(f"*{suffix}")
        if p.is_file()
    )
    return files


def nested_groups(file_paths: list[str], root_name: str) -> dict[str, dict]:
    """Build a tree of groups keyed by posix path relative to repo root."""
    tree: dict[str, dict] = {
        root_name: {"path": root_name, "name": root_name, "subgroups": {}, "files": []}
    }

    for rel in file_paths:
        parts = rel.split("/")
        current_key = parts[0]
        node = tree[current_key]
        for part in parts[1:-1]:
            if part not in node["subgroups"]:
                child_key = f"{current_key}/{part}"
                node["subgroups"][part] = {
                    "path": part,
                    "name": part,
                    "key": child_key,
                    "subgroups": {},
                    "files": [],
                }
            node = node["subgroups"][part]
            current_key = node.get("key", f"{current_key}/{part}")
        node["files"].append(rel)
    return tree


def emit_groups(tree_root: dict, lines: list[str], group_ids: dict[str, str]) -> None:
    def walk(node: dict, key: str) -> None:
        gid = group_ids[key]
        child_ids: list[tuple[str, str]] = []
        for name, child in sorted(node["subgroups"].items()):
            child_key = child.get("key") or f"{key}/{name}"
            child_ids.append((child["name"], group_ids[child_key]))
            walk(child, child_key)
        file_entries = [(Path(f).name, uid("file", f)) for f in node["files"]]
        children = child_ids + file_entries
        children_block = "".join(
            f"\t\t\t\t{cid} /* {name} */,\n" for name, cid in children
        )
        path = node["path"]
        lines.append(f"\t\t{gid} /* {node['name']} */ = {{")
        lines.append("\t\t\tisa = PBXGroup;")
        lines.append("\t\t\tchildren = (")
        lines.append(children_block)
        lines.append("\t\t\t);")
        lines.append(f"\t\t\tpath = {path};")
        lines.append("\t\t\tsourceTree = \"<group>\";")
        lines.append("\t\t};")

    walk(tree_root, tree_root["name"])


def assign_group_ids(node: dict, key: str, group_ids: dict[str, str]) -> None:
    group_ids[key] = uid("group", key)
    for name, child in node["subgroups"].items():
        child_key = child.get("key") or f"{key}/{name}"
        assign_group_ids(child, child_key, group_ids)


def pbx_value(value: str) -> str:
    if any(ch in value for ch in ' \t+$()[]{}<>!#,&*?') or not value:
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'
    return value


def pbx_settings(rows: dict[str, str], indent: str = "\t\t\t\t") -> str:
    out = []
    for key, value in rows.items():
        out.append(f"{indent}{key} = {value};")
    return "\n".join(out)


def main() -> None:
    sources = collect_files("Sources", ".swift")
    tests = collect_files("Tests", ".swift")
    if not sources:
        raise SystemExit("No Swift sources found")

    sources_tree = nested_groups(sources, "Sources")["Sources"]
    tests_tree = nested_groups(tests, "Tests")["Tests"]

    project_id = uid("project")
    main_group_id = uid("group", "main")
    products_group_id = uid("group", "products")
    # iOS .app 里不能出现名为 Resources 的文件夹，否则安装器会去那里找 Info.plist
    # 从而报 Missing bundle ID。把 Config 作为独立文件夹打进包内即可。
    config_ref_id = uid("file", "Resources/Config")
    localization_ref_id = uid("file", "Resources/Localization")
    assets_ref_id = uid("file", "Assets.xcassets")
    app_product_id = uid("product", "LifeRPG.app")
    test_product_id = uid("product", "LifeRPGTests.xctest")
    app_target_id = uid("target", "LifeRPG")
    test_target_id = uid("target", "LifeRPGTests")
    app_sources_phase_id = uid("phase", "app-sources")
    app_resources_phase_id = uid("phase", "app-resources")
    app_frameworks_phase_id = uid("phase", "app-frameworks")
    test_sources_phase_id = uid("phase", "test-sources")
    test_resources_phase_id = uid("phase", "test-resources")
    test_frameworks_phase_id = uid("phase", "test-frameworks")
    project_debug_id = uid("config", "project-debug")
    project_release_id = uid("config", "project-release")
    app_debug_id = uid("config", "app-debug")
    app_release_id = uid("config", "app-release")
    test_debug_id = uid("config", "test-debug")
    test_release_id = uid("config", "test-release")
    project_config_list_id = uid("configlist", "project")
    app_config_list_id = uid("configlist", "app")
    test_config_list_id = uid("configlist", "test")
    proxy_id = uid("proxy", "tests->app")
    dependency_id = uid("dependency", "tests->app")
    app_resource_build_id = uid("build", "Config", "app")
    test_resource_build_id = uid("build", "Config", "test")
    app_l10n_build_id = uid("build", "Localization", "app")
    test_l10n_build_id = uid("build", "Localization", "test")
    app_assets_build_id = uid("build", "Assets.xcassets", "app")

    source_file_ids = {path: uid("file", path) for path in sources}
    test_file_ids = {path: uid("file", path) for path in tests}
    app_build_ids = {path: uid("build", path, "app") for path in sources}
    test_build_ids = {path: uid("build", path, "test") for path in tests}

    group_ids: dict[str, str] = {}
    assign_group_ids(sources_tree, "Sources", group_ids)
    assign_group_ids(tests_tree, "Tests", group_ids)
    sources_group_id = group_ids["Sources"]
    tests_group_id = group_ids["Tests"]

    objects: list[str] = []

    # PBXBuildFile
    objects.append("/* Begin PBXBuildFile section */")
    for path in sources:
        name = Path(path).name
        objects.append(
            f"\t\t{app_build_ids[path]} /* {name} in Sources */ = "
            f"{{isa = PBXBuildFile; fileRef = {source_file_ids[path]} /* {name} */; }};"
        )
    objects.append(
        f"\t\t{app_resource_build_id} /* Config in Resources */ = "
        f"{{isa = PBXBuildFile; fileRef = {config_ref_id} /* Config */; }};"
    )
    objects.append(
        f"\t\t{app_l10n_build_id} /* Localization in Resources */ = "
        f"{{isa = PBXBuildFile; fileRef = {localization_ref_id} /* Localization */; }};"
    )
    objects.append(
        f"\t\t{app_assets_build_id} /* Assets.xcassets in Resources */ = "
        f"{{isa = PBXBuildFile; fileRef = {assets_ref_id} /* Assets.xcassets */; }};"
    )
    for path in tests:
        name = Path(path).name
        objects.append(
            f"\t\t{test_build_ids[path]} /* {name} in Sources */ = "
            f"{{isa = PBXBuildFile; fileRef = {test_file_ids[path]} /* {name} */; }};"
        )
    objects.append(
        f"\t\t{test_resource_build_id} /* Config in Resources */ = "
        f"{{isa = PBXBuildFile; fileRef = {config_ref_id} /* Config */; }};"
    )
    objects.append(
        f"\t\t{test_l10n_build_id} /* Localization in Resources */ = "
        f"{{isa = PBXBuildFile; fileRef = {localization_ref_id} /* Localization */; }};"
    )
    objects.append("/* End PBXBuildFile section */\n")

    # PBXContainerItemProxy
    objects.append("/* Begin PBXContainerItemProxy section */")
    objects.append(f"\t\t{proxy_id} /* PBXContainerItemProxy */ = {{")
    objects.append("\t\t\tisa = PBXContainerItemProxy;")
    objects.append(f"\t\t\tcontainerPortal = {project_id} /* Project object */;")
    objects.append("\t\t\tproxyType = 1;")
    objects.append(f"\t\t\tremoteGlobalIDString = {app_target_id};")
    objects.append("\t\t\tremoteInfo = LifeRPG;")
    objects.append("\t\t};")
    objects.append("/* End PBXContainerItemProxy section */\n")

    # PBXFileReference
    objects.append("/* Begin PBXFileReference section */")
    objects.append(
        f"\t\t{app_product_id} /* LifeRPG.app */ = "
        "{isa = PBXFileReference; explicitFileType = wrapper.application; "
        "includeInIndex = 0; path = LifeRPG.app; sourceTree = BUILT_PRODUCTS_DIR; };"
    )
    objects.append(
        f"\t\t{test_product_id} /* LifeRPGTests.xctest */ = "
        "{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; "
        "includeInIndex = 0; path = LifeRPGTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };"
    )
    objects.append(
        f"\t\t{config_ref_id} /* Config */ = "
        "{isa = PBXFileReference; lastKnownFileType = folder; name = Config; "
        'path = Resources/Config; sourceTree = "<group>"; };'
    )
    objects.append(
        f"\t\t{localization_ref_id} /* Localization */ = "
        "{isa = PBXFileReference; lastKnownFileType = folder; name = Localization; "
        'path = Resources/Localization; sourceTree = "<group>"; };'
    )
    objects.append(
        f"\t\t{assets_ref_id} /* Assets.xcassets */ = "
        "{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; "
        'path = Assets.xcassets; sourceTree = "<group>"; };'
    )
    for path, fid in {**source_file_ids, **test_file_ids}.items():
        name = Path(path).name
        objects.append(
            f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; "
            f"path = {pbx_value(name)}; sourceTree = \"<group>\"; }};"
        )
    objects.append("/* End PBXFileReference section */\n")

    # PBXFrameworksBuildPhase
    objects.append("/* Begin PBXFrameworksBuildPhase section */")
    for phase_id, comment in (
        (app_frameworks_phase_id, "Frameworks"),
        (test_frameworks_phase_id, "Frameworks"),
    ):
        objects.append(f"\t\t{phase_id} /* {comment} */ = {{")
        objects.append("\t\t\tisa = PBXFrameworksBuildPhase;")
        objects.append("\t\t\tbuildActionMask = 2147483647;")
        objects.append("\t\t\tfiles = (")
        objects.append("\t\t\t);")
        objects.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        objects.append("\t\t};")
    objects.append("/* End PBXFrameworksBuildPhase section */\n")

    # PBXGroup
    objects.append("/* Begin PBXGroup section */")
    objects.append(f"\t\t{main_group_id} = {{")
    objects.append("\t\t\tisa = PBXGroup;")
    objects.append("\t\t\tchildren = (")
    objects.append(f"\t\t\t\t{sources_group_id} /* Sources */,")
    objects.append(f"\t\t\t\t{assets_ref_id} /* Assets.xcassets */,")
    objects.append(f"\t\t\t\t{config_ref_id} /* Config */,")
    objects.append(f"\t\t\t\t{localization_ref_id} /* Localization */,")
    objects.append(f"\t\t\t\t{tests_group_id} /* Tests */,")
    objects.append(f"\t\t\t\t{products_group_id} /* Products */,")
    objects.append("\t\t\t);")
    objects.append("\t\t\tsourceTree = \"<group>\";")
    objects.append("\t\t};")
    objects.append(f"\t\t{products_group_id} /* Products */ = {{")
    objects.append("\t\t\tisa = PBXGroup;")
    objects.append("\t\t\tchildren = (")
    objects.append(f"\t\t\t\t{app_product_id} /* LifeRPG.app */,")
    objects.append(f"\t\t\t\t{test_product_id} /* LifeRPGTests.xctest */,")
    objects.append("\t\t\t);")
    objects.append("\t\t\tname = Products;")
    objects.append("\t\t\tsourceTree = \"<group>\";")
    objects.append("\t\t};")
    emit_groups(sources_tree, objects, group_ids)
    emit_groups(tests_tree, objects, group_ids)
    objects.append("/* End PBXGroup section */\n")

    # PBXNativeTarget
    objects.append("/* Begin PBXNativeTarget section */")
    objects.append(f"\t\t{app_target_id} /* LifeRPG */ = {{")
    objects.append("\t\t\tisa = PBXNativeTarget;")
    objects.append(f"\t\t\tbuildConfigurationList = {app_config_list_id} /* Build configuration list for PBXNativeTarget \"LifeRPG\" */;")
    objects.append("\t\t\tbuildPhases = (")
    objects.append(f"\t\t\t\t{app_sources_phase_id} /* Sources */,")
    objects.append(f"\t\t\t\t{app_frameworks_phase_id} /* Frameworks */,")
    objects.append(f"\t\t\t\t{app_resources_phase_id} /* Resources */,")
    objects.append("\t\t\t);")
    objects.append("\t\t\tbuildRules = (")
    objects.append("\t\t\t);")
    objects.append("\t\t\tdependencies = (")
    objects.append("\t\t\t);")
    objects.append("\t\t\tname = LifeRPG;")
    objects.append(f"\t\t\tproductName = LifeRPG;")
    objects.append(f"\t\t\tproductReference = {app_product_id} /* LifeRPG.app */;")
    objects.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    objects.append("\t\t};")
    objects.append(f"\t\t{test_target_id} /* LifeRPGTests */ = {{")
    objects.append("\t\t\tisa = PBXNativeTarget;")
    objects.append(f"\t\t\tbuildConfigurationList = {test_config_list_id} /* Build configuration list for PBXNativeTarget \"LifeRPGTests\" */;")
    objects.append("\t\t\tbuildPhases = (")
    objects.append(f"\t\t\t\t{test_sources_phase_id} /* Sources */,")
    objects.append(f"\t\t\t\t{test_frameworks_phase_id} /* Frameworks */,")
    objects.append(f"\t\t\t\t{test_resources_phase_id} /* Resources */,")
    objects.append("\t\t\t);")
    objects.append("\t\t\tbuildRules = (")
    objects.append("\t\t\t);")
    objects.append("\t\t\tdependencies = (")
    objects.append(f"\t\t\t\t{dependency_id} /* PBXTargetDependency */,")
    objects.append("\t\t\t);")
    objects.append("\t\t\tname = LifeRPGTests;")
    objects.append("\t\t\tproductName = LifeRPGTests;")
    objects.append(f"\t\t\tproductReference = {test_product_id} /* LifeRPGTests.xctest */;")
    objects.append("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
    objects.append("\t\t};")
    objects.append("/* End PBXNativeTarget section */\n")

    # PBXProject
    objects.append("/* Begin PBXProject section */")
    objects.append(f"\t\t{project_id} /* Project object */ = {{")
    objects.append("\t\t\tisa = PBXProject;")
    objects.append("\t\t\tattributes = {")
    objects.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    objects.append("\t\t\t\tLastSwiftUpdateCheck = 1600;")
    objects.append("\t\t\t\tLastUpgradeCheck = 1600;")
    objects.append("\t\t\t\tTargetAttributes = {")
    objects.append(f"\t\t\t\t\t{app_target_id} = {{")
    objects.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    objects.append("\t\t\t\t\t};")
    objects.append(f"\t\t\t\t\t{test_target_id} = {{")
    objects.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    objects.append(f"\t\t\t\t\t\tTestTargetID = {app_target_id};")
    objects.append("\t\t\t\t\t};")
    objects.append("\t\t\t\t};")
    objects.append("\t\t\t};")
    objects.append(f"\t\t\tbuildConfigurationList = {project_config_list_id} /* Build configuration list for PBXProject \"LifeRPG\" */;")
    objects.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    objects.append("\t\t\tdevelopmentRegion = en;")
    objects.append("\t\t\thasScannedForEncodings = 0;")
    objects.append("\t\t\tknownRegions = (")
    objects.append("\t\t\t\ten,")
    objects.append("\t\t\t\t\"zh-Hans\",")
    objects.append("\t\t\t\tBase,")
    objects.append("\t\t\t);")
    objects.append(f"\t\t\tmainGroup = {main_group_id};")
    objects.append(f"\t\t\tproductRefGroup = {products_group_id} /* Products */;")
    objects.append("\t\t\tprojectDirPath = \"\";")
    objects.append("\t\t\tprojectRoot = \"\";")
    objects.append("\t\t\ttargets = (")
    objects.append(f"\t\t\t\t{app_target_id} /* LifeRPG */,")
    objects.append(f"\t\t\t\t{test_target_id} /* LifeRPGTests */,")
    objects.append("\t\t\t);")
    objects.append("\t\t};")
    objects.append("/* End PBXProject section */\n")

    # PBXResourcesBuildPhase
    objects.append("/* Begin PBXResourcesBuildPhase section */")
    objects.append(f"\t\t{app_resources_phase_id} /* Resources */ = {{")
    objects.append("\t\t\tisa = PBXResourcesBuildPhase;")
    objects.append("\t\t\tbuildActionMask = 2147483647;")
    objects.append("\t\t\tfiles = (")
    objects.append(f"\t\t\t\t{app_resource_build_id} /* Config in Resources */,")
    objects.append(f"\t\t\t\t{app_l10n_build_id} /* Localization in Resources */,")
    objects.append(f"\t\t\t\t{app_assets_build_id} /* Assets.xcassets in Resources */,")
    objects.append("\t\t\t);")
    objects.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    objects.append("\t\t};")
    objects.append(f"\t\t{test_resources_phase_id} /* Resources */ = {{")
    objects.append("\t\t\tisa = PBXResourcesBuildPhase;")
    objects.append("\t\t\tbuildActionMask = 2147483647;")
    objects.append("\t\t\tfiles = (")
    objects.append(f"\t\t\t\t{test_resource_build_id} /* Config in Resources */,")
    objects.append(f"\t\t\t\t{test_l10n_build_id} /* Localization in Resources */,")
    objects.append("\t\t\t);")
    objects.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    objects.append("\t\t};")
    objects.append("/* End PBXResourcesBuildPhase section */\n")

    # PBXSourcesBuildPhase
    objects.append("/* Begin PBXSourcesBuildPhase section */")
    objects.append(f"\t\t{app_sources_phase_id} /* Sources */ = {{")
    objects.append("\t\t\tisa = PBXSourcesBuildPhase;")
    objects.append("\t\t\tbuildActionMask = 2147483647;")
    objects.append("\t\t\tfiles = (")
    for path in sources:
        objects.append(f"\t\t\t\t{app_build_ids[path]} /* {Path(path).name} in Sources */,")
    objects.append("\t\t\t);")
    objects.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    objects.append("\t\t};")
    objects.append(f"\t\t{test_sources_phase_id} /* Sources */ = {{")
    objects.append("\t\t\tisa = PBXSourcesBuildPhase;")
    objects.append("\t\t\tbuildActionMask = 2147483647;")
    objects.append("\t\t\tfiles = (")
    for path in tests:
        objects.append(f"\t\t\t\t{test_build_ids[path]} /* {Path(path).name} in Sources */,")
    objects.append("\t\t\t);")
    objects.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    objects.append("\t\t};")
    objects.append("/* End PBXSourcesBuildPhase section */\n")

    # PBXTargetDependency
    objects.append("/* Begin PBXTargetDependency section */")
    objects.append(f"\t\t{dependency_id} /* PBXTargetDependency */ = {{")
    objects.append("\t\t\tisa = PBXTargetDependency;")
    objects.append(f"\t\t\ttarget = {app_target_id} /* LifeRPG */;")
    objects.append(f"\t\t\ttargetProxy = {proxy_id} /* PBXContainerItemProxy */;")
    objects.append("\t\t};")
    objects.append("/* End PBXTargetDependency section */\n")

    project_common = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
        "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "CLANG_ENABLE_OBJC_WEAK": "YES",
        "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
        "CLANG_WARN_BOOL_CONVERSION": "YES",
        "CLANG_WARN_COMMA": "YES",
        "CLANG_WARN_CONSTANT_CONVERSION": "YES",
        "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
        "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
        "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
        "CLANG_WARN_EMPTY_BODY": "YES",
        "CLANG_WARN_ENUM_CONVERSION": "YES",
        "CLANG_WARN_INFINITE_RECURSION": "YES",
        "CLANG_WARN_INT_CONVERSION": "YES",
        "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
        "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
        "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
        "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
        "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
        "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
        "CLANG_WARN_STRICT_PROTOTYPES": "YES",
        "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
        "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
        "CLANG_WARN_UNREACHABLE_CODE": "YES",
        "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES",
        "COPY_PHASE_STRIP": "NO",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
        "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
        "GCC_WARN_UNDECLARED_SELECTOR": "YES",
        "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
        "GCC_WARN_UNUSED_FUNCTION": "YES",
        "GCC_WARN_UNUSED_VARIABLE": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "SDKROOT": "iphoneos",
        "SWIFT_STRICT_CONCURRENCY": "minimal",
        "SWIFT_VERSION": "5.9",
    }

    debug_extra = {
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "GCC_DYNAMIC_NO_PIC": "NO",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "GCC_PREPROCESSOR_DEFINITIONS": "(\n\t\t\t\t\t\"DEBUG=1\",\n\t\t\t\t\t\"$(inherited)\",\n\t\t\t\t)",
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "ONLY_ACTIVE_ARCH": "YES",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": '"DEBUG $(inherited)"',
        "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
    }
    release_extra = {
        "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
        "ENABLE_NS_ASSERTIONS": "NO",
        "MTL_ENABLE_DEBUG_INFO": "NO",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "SWIFT_OPTIMIZATION_LEVEL": '"-O"',
        "VALIDATE_PRODUCT": "YES",
    }

    app_settings = {
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": '""',
        "ENABLE_PREVIEWS": "YES",
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "GENERATE_INFOPLIST_FILE": "YES",
        "INFOPLIST_KEY_CFBundleDisplayName": '"Life RPG"',
        "INFOPLIST_KEY_NSCameraUsageDescription": '"用于拍摄自定义角色头像"',
        "INFOPLIST_KEY_NSPhotoLibraryUsageDescription": '"用于选择自定义角色头像"',
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
        "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations": "UIInterfaceOrientationPortrait",
        "LD_RUNPATH_SEARCH_PATHS": "(\n\t\t\t\t\t\"$(inherited)\",\n\t\t\t\t\t\"@executable_path/Frameworks\",\n\t\t\t\t)",
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.liferpg.app",
        "PRODUCT_MODULE_NAME": "LifeRPG",
        "PRODUCT_NAME": "LifeRPG",
        "SUPPORTED_PLATFORMS": '"iphoneos iphonesimulator"',
        "SUPPORTS_MACCATALYST": "NO",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_STRICT_CONCURRENCY": "minimal",
        "SWIFT_VERSION": "5.9",
        "TARGETED_DEVICE_FAMILY": '"1"',
    }

    test_settings = {
        "BUNDLE_LOADER": '"$(TEST_HOST)"',
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": '""',
        "GENERATE_INFOPLIST_FILE": "YES",
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.liferpg.app.tests",
        "PRODUCT_NAME": '"$(TARGET_NAME)"',
        "SUPPORTED_PLATFORMS": '"iphoneos iphonesimulator"',
        "SWIFT_EMIT_LOC_STRINGS": "NO",
        "SWIFT_STRICT_CONCURRENCY": "minimal",
        "SWIFT_VERSION": "5.9",
        "TARGETED_DEVICE_FAMILY": '"1"',
        "TEST_HOST": '"$(BUILT_PRODUCTS_DIR)/LifeRPG.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/LifeRPG"',
    }

    objects.append("/* Begin XCBuildConfiguration section */")
    for cid, name, extra in (
        (project_debug_id, "Debug", debug_extra),
        (project_release_id, "Release", release_extra),
    ):
        objects.append(f"\t\t{cid} /* {name} */ = {{")
        objects.append("\t\t\tisa = XCBuildConfiguration;")
        objects.append("\t\t\tbuildSettings = {")
        objects.append(pbx_settings({**project_common, **extra}))
        objects.append("\t\t\t};")
        objects.append(f"\t\t\tname = {name};")
        objects.append("\t\t};")

    for cid, name, settings in (
        (app_debug_id, "Debug", app_settings),
        (app_release_id, "Release", app_settings),
        (test_debug_id, "Debug", test_settings),
        (test_release_id, "Release", test_settings),
    ):
        objects.append(f"\t\t{cid} /* {name} */ = {{")
        objects.append("\t\t\tisa = XCBuildConfiguration;")
        objects.append("\t\t\tbuildSettings = {")
        objects.append(pbx_settings(settings))
        objects.append("\t\t\t};")
        objects.append(f"\t\t\tname = {name};")
        objects.append("\t\t};")
    objects.append("/* End XCBuildConfiguration section */\n")

    objects.append("/* Begin XCConfigurationList section */")
    for lid, comment, debug_id, release_id in (
        (project_config_list_id, 'Build configuration list for PBXProject "LifeRPG"', project_debug_id, project_release_id),
        (app_config_list_id, 'Build configuration list for PBXNativeTarget "LifeRPG"', app_debug_id, app_release_id),
        (test_config_list_id, 'Build configuration list for PBXNativeTarget "LifeRPGTests"', test_debug_id, test_release_id),
    ):
        objects.append(f"\t\t{lid} /* {comment} */ = {{")
        objects.append("\t\t\tisa = XCConfigurationList;")
        objects.append("\t\t\tbuildConfigurations = (")
        objects.append(f"\t\t\t\t{debug_id} /* Debug */,")
        objects.append(f"\t\t\t\t{release_id} /* Release */,")
        objects.append("\t\t\t);")
        objects.append("\t\t\tdefaultConfigurationIsVisible = 0;")
        objects.append("\t\t\tdefaultConfigurationName = Release;")
        objects.append("\t\t};")
    objects.append("/* End XCConfigurationList section */")

    pbxproj = "\n".join(
        [
            "// !$*UTF8*$!",
            "{",
            "\tarchiveVersion = 1;",
            "\tclasses = {",
            "\t};",
            "\tobjectVersion = 56;",
            "\tobjects = {",
            "",
            *objects,
            "\t};",
            f"\trootObject = {project_id} /* Project object */;",
            "}",
            "",
        ]
    )

    scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{app_target_id}"
               BuildableName = "LifeRPG.app"
               BlueprintName = "LifeRPG"
               ReferencedContainer = "container:LifeRPG.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference
            skipped = "NO"
            parallelizable = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{test_target_id}"
               BuildableName = "LifeRPGTests.xctest"
               BlueprintName = "LifeRPGTests"
               ReferencedContainer = "container:LifeRPG.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target_id}"
            BuildableName = "LifeRPG.app"
            BlueprintName = "LifeRPG"
            ReferencedContainer = "container:LifeRPG.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target_id}"
            BuildableName = "LifeRPG.app"
            BlueprintName = "LifeRPG"
            ReferencedContainer = "container:LifeRPG.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""

    workspace = """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
"""

    (PROJECT_DIR / "project.xcworkspace").mkdir(parents=True, exist_ok=True)
    (PROJECT_DIR / "xcshareddata" / "xcschemes").mkdir(parents=True, exist_ok=True)
    (PROJECT_DIR / "project.pbxproj").write_text(pbxproj, encoding="utf-8")
    (PROJECT_DIR / "project.xcworkspace" / "contents.xcworkspacedata").write_text(
        workspace, encoding="utf-8"
    )
    (PROJECT_DIR / "xcshareddata" / "xcschemes" / "LifeRPG.xcscheme").write_text(
        scheme, encoding="utf-8"
    )
    print(f"Generated {PROJECT_DIR}")
    print(f"  sources: {len(sources)}")
    print(f"  tests:   {len(tests)}")


if __name__ == "__main__":
    main()
