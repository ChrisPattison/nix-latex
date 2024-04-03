(final: prev:
let
  pythonPackageOverlay = self: super: {
    arxiv-latex-cleaner = self.callPackage ./arxiv-latex-cleaner { };
  };
in
{
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [ pythonPackageOverlay ];
})

