defmodule RustlerElixirFunTest do
  use ExUnit.Case
  doctest RustlerElixirFun

  test "greets the world" do
    assert RustlerElixirFun.hello() == :world
  end
end
