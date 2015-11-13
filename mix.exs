defmodule Hamcrest.Mixfile do
  use Mix.Project

  @version File.read!("VERSION") |> String.strip

  def project do
    [app: :hamcrest,
     version: @version,
     description: "Erlang port of Hamcrest",
     package: package(),
     deps: deps(),
     erlc_options: erlc_options()]
  end

  defp erlc_options do
    extra_options = try do
      case :erlang.list_to_integer(:erlang.system_info(:otp_release)) do
        v when v >= 17 ->
          [{:d, :namespaced_types}]
        _ ->
          []
      end
    catch
      _ ->
        []
    end
    [:debug_info, :warnings_as_errors, :fail_on_warning | extra_options]
  end

  defp deps do
    [{:ex_doc, ">= 0.0.0", only: :dev}]
  end

  defp package do
    [name: "basho_hamcrest",
     files: ~w(mix.exs ebin/hamcrest.app include priv src test INSTALL LICENCE Makefile NOTES README.markdown rebar.config test.config TODO.md VERSION),
     maintainers: ["Tim Watson", "Luke Bakken"],
     licenses: ["Copyright (c) 2010, Tim Watson"],
     links: %{"GitHub" => "https://github.com/basho/hamcrest-erlang",
              "Upstream" => "https://github.com/hyperthunk/hamcrest-erlang"}]
  end
end
