# Extract NixOS service options as JSON
# Usage: nix eval --json \
#          --apply "f: f { serviceName = \"redis\"; }" \
#          --file scripts/extract-options.nix > services/redis/defaults.json

{
  serviceName,
}:

let
  # Hardcoded nixpkgs reference - update this when changing NixOS version
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-25.11.tar.gz";
  };

  pkgs = import nixpkgs { system = builtins.currentSystem; };
  lib = pkgs.lib;

  # Get nixpkgs version implicitly
  nixpkgsVersion = lib.version;

  # Evaluate NixOS with minimal configuration
  nixosEval = import (nixpkgs + "/nixos/lib/eval-config.nix") {
    system = builtins.currentSystem;
    modules = [ { } ];
  };

  options = nixosEval.options;

  # Service name mappings for services with different NixOS names
  serviceNameMappings = {
    "postgres" = "postgresql";
    "kafka" = "apache-kafka";
    # prometheus uses its own name, no mapping needed
  };

  # Resolve the actual NixOS service name
  resolvedServiceName = serviceNameMappings.${serviceName} or serviceName;

  # Check if the service exists
  serviceExists = options.services ? ${resolvedServiceName};

  # Get the service options (or empty if not found)
  serviceOpts = if serviceExists then options.services.${resolvedServiceName} else { };

  # Check if an attribute set is a NixOS option definition
  isOption = x: builtins.isAttrs x && x ? _type && x._type == "option";

  # Check if a type is attrsOf (submodule ...) or attrsWith (submodule ...)
  isAttrsOfSubmodule =
    t:
    t != null
    && t ? functor
    && (t.functor.name or "" == "attrsOf" || t.functor.name or "" == "attrsWith")
    && t ? nestedTypes
    && t.nestedTypes ? elemType
    && (
      t.nestedTypes.elemType ? getSubOptions
      || (t.nestedTypes.elemType ? functor && t.nestedTypes.elemType.functor.name or "" == "submodule")
    );

  # Get submodule options from attrsOf submodule type
  getSubmoduleOpts =
    t: if t.nestedTypes.elemType ? getSubOptions then t.nestedTypes.elemType.getSubOptions [ ] else { };

  # Map NixOS type to simplified JSON type
  mapType =
    t:
    let
      desc = lib.toLower (t.description or t.name or "unknown");
      # Also check functor name for more accurate detection
      functorName = t.functor.name or "";
    in
    # Check functor name first for accurate type detection
    if functorName == "bool" then
      "boolean"
    else if functorName == "int" then
      "integer"
    else if functorName == "str" then
      "string"
    else if functorName == "path" then
      "string"
    else if functorName == "enum" then
      "string"
    else if functorName == "listOf" then
      "list"
    else if functorName == "attrsOf" || functorName == "attrsWith" then
      "map"
    else if functorName == "submodule" then
      "map"
    # Fall back to description-based detection
    else if lib.hasPrefix "bool" desc then
      "boolean"
    else if lib.hasPrefix "positive" desc then
      "integer"
    else if lib.hasPrefix "nonnegative" desc then
      "integer"
    else if lib.hasPrefix "signed integer" desc then
      "integer"
    else if lib.hasPrefix "unsigned integer" desc then
      "integer"
    else if lib.hasPrefix "16 bit" desc then
      "integer"
    else if lib.hasPrefix "32 bit" desc then
      "integer"
    else if lib.hasPrefix "port" desc then
      "integer"
    else if desc == "int" then
      "integer"
    else if lib.hasPrefix "string" desc then
      "string"
    else if desc == "str" then
      "string"
    else if lib.hasPrefix "null or string" desc then
      "string"
    else if lib.hasPrefix "null or str" desc then
      "string"
    else if lib.hasPrefix "path" desc then
      "string"
    else if lib.hasPrefix "null or path" desc then
      "string"
    else if lib.hasPrefix "one of" desc then
      "string"
    else if lib.hasPrefix "list of" desc then
      "list"
    else if lib.hasPrefix "attribute set" desc then
      "map"
    else if lib.hasPrefix "package" desc then
      "string"
    else if lib.hasPrefix "null or package" desc then
      "string"
    else
      "any";

  # Extract enum values from type
  getEnum =
    opt:
    let
      t = opt.type or null;
    in
    if t == null then
      null
    else if t ? functor && t.functor.name or "" == "enum" then
      t.functor.payload or null
    # Handle nullOr enum
    else if
      t ? functor
      && t.functor.name or "" == "nullOr"
      && t ? nestedTypes
      && t.nestedTypes ? elemType
      && t.nestedTypes.elemType ? functor
      && t.nestedTypes.elemType.functor.name or "" == "enum"
    then
      t.nestedTypes.elemType.functor.payload or null
    else
      null;

  # Check if option is read-only
  isReadOnly = opt: opt.readOnly or false;

  # Check if option is required (has no default)
  isRequired = opt: !(opt ? default);

  # Safely evaluate a default value to JSON-compatible format
  evaluateDefault =
    opt:
    if !(opt ? default) then
      null
    else
      let
        # Use tryEval to handle options that throw when accessed
        tryDefault = builtins.tryEval opt.default;
      in
      if !tryDefault.success then
        null
      else
        let
          raw = tryDefault.value;
        in
        if raw == null then
          null
        else if lib.isDerivation raw then
          null # Package defaults handled separately
        else if builtins.isPath raw then
          toString raw
        else if builtins.isFunction raw then
          null
        else if builtins.isBool raw then
          raw
        else if builtins.isInt raw then
          raw
        else if builtins.isFloat raw then
          raw
        else if builtins.isString raw then
          raw
        else if builtins.isList raw then
          let
            serialized = map (
              x:
              if builtins.isString x then
                x
              else if builtins.isInt x then
                x
              else if builtins.isBool x then
                x
              else if builtins.isFloat x then
                x
              else if x == null then
                null
              else
                null # Can't serialize complex list elements
            ) raw;
          in
          # Only return if all elements were serializable
          if builtins.all (x: x != null || builtins.elem null raw) serialized then serialized else [ ]
        else if builtins.isAttrs raw then
          if raw ? _type then
            # Special types like literalExpression - can't serialize
            null
          else
            # Try to serialize simple attrset
            let
              serialized = lib.mapAttrs (
                n: v:
                if builtins.isString v then
                  v
                else if builtins.isInt v then
                  v
                else if builtins.isBool v then
                  v
                else if builtins.isFloat v then
                  v
                else if v == null then
                  null
                else
                  "__UNSERIALIZABLE__"
              ) raw;
            in
            if builtins.all (v: v != "__UNSERIALIZABLE__") (builtins.attrValues serialized) then
              serialized
            else
              { }
        else
          null;

  # Evaluate example value
  evaluateExample =
    opt:
    if !(opt ? example) then
      null
    else
      let
        raw = opt.example;
      in
      if raw == null then
        null
      else if builtins.isAttrs raw && raw ? _type then
        if raw._type == "literalExpression" then
          raw.text or null
        else if raw._type == "literalMD" then
          raw.text or null
        else
          null
      else if lib.isDerivation raw then
        null
      else if builtins.isPath raw then
        toString raw
      else if builtins.isFunction raw then
        null
      else if builtins.isBool raw then
        raw
      else if builtins.isInt raw then
        raw
      else if builtins.isFloat raw then
        raw
      else if builtins.isString raw then
        raw
      else if builtins.isList raw then
        raw # Simplified
      else if builtins.isAttrs raw then
        raw # Simplified
      else
        null;

  # Get description text
  getDescription =
    opt:
    if !(opt ? description) then
      ""
    else if builtins.isString opt.description then
      opt.description
    else if builtins.isAttrs opt.description && opt.description ? text then
      opt.description.text
    else
      "";

  # Create setting info object
  makeSettingInfo = opt: {
    type = mapType (opt.type or { name = "unknown"; });
    default = evaluateDefault opt;
    required = isRequired opt;
    readOnly = isReadOnly opt;
    description = getDescription opt;
    example = evaluateExample opt;
    enum = getEnum opt;
  };

  # Extract package info from an option
  extractPackageFromOpt =
    opt:
    let
      # Use tryEval to handle options that throw when accessed
      tryDefault = builtins.tryEval (opt.default or null);
      default = if tryDefault.success then tryDefault.value else null;
    in
    if default == null then
      null
    else if lib.isDerivation default then
      {
        name =
          if default ? pname && default.pname != null then
            default.pname
          else if default ? name && default.name != null then
            lib.getName default
          else
            "unknown";
        version = default.version or null;
      }
    else
      null;

  # Find and extract package info from service options
  extractPackage =
    opts:
    let
      # First check for direct package option
      directPkg =
        if opts ? package && isOption opts.package then extractPackageFromOpt opts.package else null;

      # If not found, check in first submodule
      submodulePkg =
        let
          submoduleOpts = lib.filterAttrs (n: v: isOption v && v ? type && isAttrsOfSubmodule v.type) opts;
        in
        if submoduleOpts == { } then
          null
        else
          let
            firstSubName = lib.head (builtins.attrNames submoduleOpts);
            firstSub = submoduleOpts.${firstSubName};
            subOpts = getSubmoduleOpts firstSub.type;
          in
          if subOpts ? package && isOption subOpts.package then
            extractPackageFromOpt subOpts.package
          else
            null;
    in
    if directPkg != null then directPkg else submodulePkg;

  # Extract settings, going into first submodule level only
  extractSettings =
    opts:
    let
      # Process options at current level
      # isInSubmodule tracks whether we've already entered a submodule
      processLevel =
        prefix: isInSubmodule: o:
        let
          # Filter out internal/private attributes
          publicAttrs = lib.filterAttrs (n: v: !(lib.hasPrefix "_" n)) o;
        in
        lib.concatMapAttrs (
          name: val:
          if isOption val then
            let
              t = val.type or null;
              fullName = if prefix == "" then name else "${prefix}.${name}";
              # Check if this is a deprecated option
              isDeprecated =
                (val.visible or true) == false
                || lib.hasInfix "deprecated" (lib.toLower (getDescription val))
                || lib.hasInfix "obsolete" (lib.toLower (getDescription val));
            in
            if name == "package" then
              { } # Skip package, handled separately
            else if isDeprecated then
              { } # Skip deprecated options
            else if t != null && isAttrsOfSubmodule t then
              if isInSubmodule then
                # Already in a submodule, don't go deeper
                # Record as a map-type setting, wrapped in tryEval
                let
                  tryInfo = builtins.tryEval (makeSettingInfo val);
                in
                if tryInfo.success then { ${fullName} = tryInfo.value; } else { }
              else
                # First submodule - extract its options
                let
                  subOpts = getSubmoduleOpts t;
                in
                processLevel "" true subOpts
            else
              # Regular option, wrapped in tryEval to handle errors
              let
                tryInfo = builtins.tryEval (makeSettingInfo val);
              in
              if tryInfo.success then { ${fullName} = tryInfo.value; } else { }
          else if builtins.isAttrs val && !(val ? _type) then
            # Namespace (not an option), recurse into it
            let
              newPrefix = if prefix == "" then name else "${prefix}.${name}";
            in
            processLevel newPrefix isInSubmodule val
          else
            { }
        ) publicAttrs;
    in
    processLevel "" false opts;

  # Build the final result
  settings = if serviceExists then extractSettings serviceOpts else { };
  package = if serviceExists then extractPackage serviceOpts else null;

  # Error message if service not found
  errorMsg =
    if serviceExists then
      null
    else
      "Service '${serviceName}' (resolved: '${resolvedServiceName}') not found in NixOS options";

in
{
  metadata = {
    nixpkgsRevision = nixpkgsVersion;
  }
  // (if errorMsg != null then { error = errorMsg; } else { });
  inherit package settings;
}
