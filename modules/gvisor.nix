{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.gvisor;
  k3sCfg = config.homelab.k3sAgent;

  # Single source of truth for the runtime handler name. This MUST match
  # the `handler` field on the cluster-side `RuntimeClass` (homelab-k8s,
  # per ADR-0003 there); if it changes there, change it here. The VM test
  # (tests/vm/services-active.nix) asserts this value is what lands in
  # containerd's config.
  handlerName = "runsc";
in
{
  options.homelab.gvisor = {
    # gVisor (`runsc`) container runtime on this k3s agent node. Companion
    # to the cluster-side `RuntimeClass` (handler `${handlerName}`) in the
    # sibling `homelab-k8s` repo — that manifest is non-functional until
    # this module installs `runsc` + its containerd shim here. See ADR-0003
    # in `homelab-k8s` for the rationale (defense in depth against
    # accidentally-executed code, not adversarial-grade isolation).
    enable = lib.mkEnableOption "the gVisor (runsc) container runtime on this k3s agent node";
  };

  config = lib.mkIf (cfg.enable && k3sCfg.enable) {
    # Add gvisor's bin dir (`runsc` + `containerd-shim-runsc-v1`) to the
    # k3s unit's PATH. NixOS builds the unit's PATH from `.path`, so this
    # concatenates onto whatever the k3s module already sets (e.g. zfs's
    # bin dir when boot.zfs.enabled) rather than overwriting it. The
    # bundled containerd looks up `containerd-shim-runsc-v1` by name on its
    # PATH, and that shim execs `runsc`, so both must be reachable.
    systemd.services.k3s.path = [ pkgs.gvisor ];

    # Register the `runsc` runtime handler in k3s's containerd config.
    # `io.containerd.runsc.v1` is gvisor's standard containerd shim runtime
    # type, served by the `containerd-shim-runsc-v1` binary placed on PATH
    # above. `{{ template "base" . }}` renders the base containerd config
    # k3s would otherwise generate on its own — the standard "merge with
    # existing config" pattern for services.k3s.containerdConfigTemplate
    # (see its own example in nixpkgs).
    services.k3s.containerdConfigTemplate = ''
      {{ template "base" . }}

      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes."${handlerName}"]
        runtime_type = "io.containerd.runsc.v1"
    '';
  };
}
