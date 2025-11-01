Gem::Specification.new do |spec|
  spec.name          = "rails-worktree"
  spec.version       = "0.1.0"
  spec.authors       = ["Martin Ulleberg"]
  spec.email         = ["martin@fasttravel.com"]

  spec.summary       = "Git worktree management for Rails projects"
  spec.description   = "Easily create, initialize, and close git worktrees with isolated databases and configurations for Rails projects"
  spec.homepage      = "https://github.com/FastTravelAS/rails-worktree"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*", "exe/**/*", "README.md", "LICENSE.txt"]
  spec.bindir = "exe"
  spec.executables = ["worktree"]
  spec.require_paths = ["lib"]
end
