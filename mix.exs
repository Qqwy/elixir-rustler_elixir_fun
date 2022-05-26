defmodule RustlerElixirFun.MixProject do
  use Mix.Project

  def project do
    [
      app: :rustler_elixir_fun,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Call back into Elixir code from within a NIF implemented in Rust",
      licenses: ["MIT"],
      source_url: "https://github.com/Qqwy/elixir-rustler_elixir_fun",
      homepage_url: "https://github.com/Qqwy/elixir-rustler_elixir_fun",
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
	    {:rustler, "~> 0.25.0"},
      {:poolboy, "~> 1.5.2"},
      {:benchee, "~> 1.0", only: [:dev, :bench]}
    ]
  end
end
