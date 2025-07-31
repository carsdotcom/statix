defmodule Statix.CachedResolver do
  @moduledoc """
  A module that provides a cached DNS resolver.
  """
  @table_name :statix_host_cache
  @resolve_cache_interval 15_000

  @spec init() :: :ok
  def init do
    :ets.new(@table_name, [:set, :public, :named_table])
    :ok
  end

  @spec get_or_resolve_ip(:inet.ip_address() | :inet.hostname()) ::
          :inet.ip_address() | no_return()
  def get_or_resolve_ip(address) when is_tuple(address), do: address

  def get_or_resolve_ip(host) do
    :ets.lookup(:statix_host_cache, host)
    |> case do
      [{_, address, expiration}] ->
        if expiration < System.monotonic_time(:millisecond) do
          true = :ets.delete(:statix_host_cache, host)
          resolve_and_cache(host)
        else
          address
        end

      _ ->
        resolve_and_cache(host)
    end
  end

  defp resolve_and_cache(host) do
    case :inet.getaddr(to_charlist(host), :inet) do
      {:ok, address} ->
        true =
          :ets.insert(
            :statix_host_cache,
            {host, address, System.monotonic_time(:millisecond) + @resolve_cache_interval}
          )

        address

      {:error, reason} ->
        raise(
          "cannot get the IP address for the provided host " <>
            "due to reason: #{:inet.format_error(reason)}"
        )
    end
  end
end
