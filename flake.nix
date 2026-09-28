{
  description = "Rivalcfg GUI for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };

          python = pkgs.python3;

          # A Python interpreter containing the complete runtime
          # dependency closure, including shiboken6 for PySide6.
          pythonRuntime = python.withPackages (ps: [
            ps.hidapi
            ps.pyside6
          ]);

          rivalcfg-gui = python.pkgs.buildPythonApplication {
            pname = "rivalcfg-gui";
            version = "4.17.0";

            src = ./.;

            pyproject = true;

            build-system = [
              python.pkgs.flit-core
            ];

            dependencies = [
              python.pkgs.hidapi
              python.pkgs.pyside6
            ];

            postInstall = ''
              # Install GUI Python files.
              mkdir -p $out/share/rivalcfg-gui
              cp -r gui/rivalcfg_gui $out/share/rivalcfg-gui/
              cp gui/run_gui.py $out/share/rivalcfg-gui/

              # Launch the GUI with a Python interpreter containing
              # PySide6, shiboken6, hidapi and their dependencies.
              makeWrapper ${pythonRuntime}/bin/python $out/bin/rivalcfg-gui \
                --add-flags "$out/share/rivalcfg-gui/run_gui.py" \
                --prefix PYTHONPATH : "$out/${python.sitePackages}" \
                --prefix PYTHONPATH : "$out/share/rivalcfg-gui"

              # Desktop entry.
              mkdir -p $out/share/applications
              cp packaging/rivalcfg-gui.desktop \
                $out/share/applications/rivalcfg-gui.desktop

              # Generate udev rules using rivalcfg itself.
              mkdir -p $out/lib/udev/rules.d
              $out/bin/rivalcfg --print-udev \
                > $out/lib/udev/rules.d/99-rivalcfg.rules
            '';
          };
        in
        {
          default = rivalcfg-gui;
          rivalcfg-gui = rivalcfg-gui;
        }
      );

      nixosModules.default = { config, lib, pkgs, ... }:
        let
          rivalcfg-gui = self.packages.${pkgs.system}.default;
        in
        {
          environment.systemPackages = [
            rivalcfg-gui
          ];

          services.udev.packages = [
            rivalcfg-gui
          ];
        };
    };
}
