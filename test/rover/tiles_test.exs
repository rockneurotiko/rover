defmodule Rover.TilesTest do
  use ExUnit.Case, async: true

  doctest Rover.Tiles

  alias Rover.Tiles

  test "every preset carries a url and an attribution" do
    for preset <- Tiles.presets() do
      resolved = Tiles.resolve!(preset)

      assert is_binary(resolved.url), "#{preset} has no url"
      assert resolved.url =~ "{z}"

      assert is_binary(resolved.attributions) and resolved.attributions != "",
             "#{preset} ships without an attribution, which is a licensing problem"
    end
  end

  test ":none means no basemap" do
    assert Tiles.resolve!(:none) == nil
  end

  test "an unknown preset lists the known ones" do
    error = assert_raise ArgumentError, fn -> Tiles.resolve!(:google_maps) end

    assert error.message =~ "unknown tile preset"
    assert error.message =~ ":carto_light"
  end

  test "xyz tiles default to zoom 19 and no attribution" do
    assert Tiles.resolve!({:xyz, "https://x/{z}/{x}/{y}.png"}) == %{
             url: "https://x/{z}/{x}/{y}.png",
             attributions: nil,
             max_zoom: 19
           }
  end

  test "xyz tiles take options" do
    resolved =
      Tiles.resolve!({:xyz, "https://x/{z}/{x}/{y}.png", max_zoom: 14, attributions: "©"})

    assert resolved.max_zoom == 14
    assert resolved.attributions == "©"
  end

  test "rejects anything else" do
    assert_raise ArgumentError, ~r/invalid tiles/, fn -> Tiles.resolve!("https://x") end
  end

  describe "carto api keys" do
    setup do
      previous = Application.get_env(:rover, Tiles)

      on_exit(fn ->
        if previous do
          Application.put_env(:rover, Tiles, previous)
        else
          Application.delete_env(:rover, Tiles)
        end
      end)
    end

    test "with no key configured, the carto url is unchanged" do
      Application.delete_env(:rover, Tiles)

      assert Tiles.resolve!(:carto_dark).url ==
               "https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
    end

    test "a configured default key is appended to every carto preset" do
      Application.put_env(:rover, Tiles, carto_api_key: "configured-key")

      for preset <- [:carto_light, :carto_dark, :carto_voyager] do
        assert Tiles.resolve!(preset).url =~ "?key=configured-key"
      end
    end

    test "a per-call key overrides the configured default" do
      Application.put_env(:rover, Tiles, carto_api_key: "configured-key")

      resolved = Tiles.resolve!({:carto_voyager, key: "call-key"})

      assert resolved.url =~ "?key=call-key"
      refute resolved.url =~ "configured-key"
    end

    test "a non-carto preset is left alone by the configured default" do
      Application.put_env(:rover, Tiles, carto_api_key: "configured-key")

      refute Tiles.resolve!(:osm).url =~ "key="
    end

    test "a key on a preset whose url already has a query string joins with &" do
      resolved = Tiles.resolve!({:ign_plan, key: "some-key"})

      assert resolved.url =~ "&key=some-key"
      refute resolved.url =~ "?key=some-key"
    end

    test "the key is url-encoded" do
      resolved = Tiles.resolve!({:carto_light, key: "a key/with+specials"})

      assert resolved.url =~ "key=a+key%2Fwith%2Bspecials"
    end
  end
end
