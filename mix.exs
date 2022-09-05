defmodule RustlerElixirFun.MixProject do
  use Mix.Project

  def project do
    [
      app: :rustler_elixir_fun,
      version: "0.3.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Call back into Elixir code from within a NIF implemented in Rust",
      package: package(),
      docs: [
        extras: ["README.md"],
        main: "readme"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
	    {:rustler, "~> 0.26.0"},
      {:poolboy, "~> 1.5.2"},
      {:benchee, "~> 1.0", only: [:dev, :bench]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      source_url: "https://github.com/Qqwy/elixir-rustler_elixir_fun",
      homepage_url: "https://github.com/Qqwy/elixir-rustler_elixir_fun",
      links: %{"GitHub" => "https://github.com/Qqwy/elixir-rustler_elixir_fun"},
      files: [
        "mix.exs",
        "lib",
        "LICENSE",
        "README.md",
        "media",
        "native/rustler_elixir_fun_nif/src",
        "native/rustler_elixir_fun_nif/Cargo.toml",
        "native/rustler_elixir_fun_nif/Cargo.lock",
      ]
    ]
  end
end
