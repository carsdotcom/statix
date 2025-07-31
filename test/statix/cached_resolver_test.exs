defmodule Statix.CachedResolverTest do
  use ExUnit.Case, async: false

  alias Statix.CachedResolver

  setup_all do
    :ok = CachedResolver.init()
  end

  describe "get_or_resolve_ip/1" do
    setup do
      # ensure the cache is empty before each test to avoid interference between tests
      :ets.delete_all_objects(:statix_host_cache)

      :ok
    end

    test "returns the IP address for a given hostname" do
      assert CachedResolver.get_or_resolve_ip("localhost") == {127, 0, 0, 1}
      assert CachedResolver.get_or_resolve_ip(~c"localhost") == {127, 0, 0, 1}
    end

    test "caches the value after resolving a hostname" do
      assert CachedResolver.get_or_resolve_ip("localhost") == {127, 0, 0, 1}
      assert [{"localhost", {127, 0, 0, 1}, _ttl}] = :ets.lookup(:statix_host_cache, "localhost")
    end

    test "uses the cached value for a given hostname" do
      :ets.insert(:statix_host_cache, {"some.test.host", {127, 0, 0, 5}, 1000})
      assert CachedResolver.get_or_resolve_ip("some.test.host") == {127, 0, 0, 5}
    end

    test "evicts the cache entry after a certain time" do
      ttl = System.monotonic_time(:millisecond) - 30
      :ets.insert(:statix_host_cache, {"localhost", {127, 0, 0, 2}, ttl})
      assert CachedResolver.get_or_resolve_ip("localhost") == {127, 0, 0, 1}

      assert [{"localhost", {127, 0, 0, 1}, new_ttl}] =
               :ets.lookup(:statix_host_cache, "localhost")

      assert new_ttl > ttl
    end

    test "returns the IP address for a given IP address" do
      assert CachedResolver.get_or_resolve_ip({127, 0, 0, 1}) == {127, 0, 0, 1}
    end

    test "raises an error for an invalid hostname" do
      assert_raise RuntimeError, fn -> CachedResolver.get_or_resolve_ip("invalid.host.name") end
    end
  end
end
