{
  description = "A flake for papers written in LaTeX";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/release-24.05";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkg_overlays = import ./overlays;
        pkgs = nixpkgs.legacyPackages.${system}.extend pkg_overlays.python;

        py = pkgs.python3.withPackages (ps: [
          ps.arxiv-latex-cleaner
        ]);

        tex = (pkgs.texlive.combine {
          inherit (pkgs.texlive)
            scheme-full latex-bin latexmk adjustbox beamer
            beamertheme-metropolis pgfopts fontspec thmtools braket quantikz
            xargs xstring environ tikz-cd tabto-ltx tikzmark collection-latex
            biblatex tikz-3dplot psnfss babel siunitx physics pgfplots mathtools
            tikzsymbols xkeyval collectbox collection-mathscience float qrcode dot2texi;
        });

        # Build derivation for latex documents
        # From https://flyx.org/nix-flakes-latex/
        # The output directory mirrors the input one but with pdf files
        latexBuildDerivation =
          ({ src, nativeBuildInputs ? [ ], texDir ? "./.", texFile, copyOutputs ? [ ] }:
            let
              buildInputs = [ pkgs.coreutils tex pkgs.asymptote pkgs.ghostscript pkgs.dot2tex ];
              copyOutputsList = builtins.concatStringsSep " " copyOutputs;
            in
            pkgs.stdenvNoCC.mkDerivation {
              name = "latex-${texFile}";
              src = src;
              allowSubstitutes = false;
              buildInputs =
                buildInputs;
              nativeBuildInputs = nativeBuildInputs;
              phases = [ "unpackPhase" "buildPhase" "installPhase" ];
              buildPhase = ''
                export PATH="${pkgs.lib.makeBinPath buildInputs}";
                mkdir -p .cache/texmf-var
                mkdir -p .asy
                ${ # Copy everything in the inputs to the build directory, preserving the directory structure
                if nativeBuildInputs == [ ] then
                  ""
                else
                  "cp -r ${
                    builtins.toString (map (s: s + "/*") nativeBuildInputs)
                  } ."}
                cd ${texDir}
                env TEXMFHOME=.cache TEXMFVAR=.cache/texmf-var \
                  ASYMPTOTE_HOME=.asy \
                  SOURCE_DATE_EPOCH=${toString self.lastModified} \
                  latexmk -interaction=nonstopmode -pdf -pdflatex \
                  -pretex="\pdfinfoomitdate1 \pdfsuppressptexinfo-1 \pdftrailerid{}" \
                  -usepretex ${texFile}.tex
              '';
              installPhase = ''
                mkdir -p $out/${texDir}
                cp ${texFile}.pdf ${copyOutputsList} $out/${texDir}
              '';
            });

        arxivCleanerBuildDerivation = ({ name ? "arxiv", src, texDir ? "./.", cleanerArgs ? ""}:
          pkgs.stdenvNoCC.mkDerivation rec {
            inherit src;
            inherit name;
            phases = [ "unpackPhase" "buildPhase" "installPhase" ];
            nativeBuildInputs = [ py ];
            buildPhase = ''
              cd ..
              mkdir clean
              cp -r $sourceRoot/${texDir} clean
              python3 -m arxiv_latex_cleaner clean ${cleanerArgs}
            '';
            installPhase = ''
              cp -r clean_arXiv $out/
            '';
          });
      in {
        lib = {
          inherit latexBuildDerivation;
          inherit arxivCleanerBuildDerivation;
        };
        formatter = pkgs.nixfmt;
      });
}
