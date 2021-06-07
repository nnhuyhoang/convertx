defmodule Convertx do
  @moduledoc ~S"""
  This module helps in convert nested struct into map.

  ## Demo

      defmodule Shop do
       use Ecto.Schema

       @primary_key {:shop_id, :id, autogenerate: true}
       schema "shop" do
         field(:name, :string)
       end
      end

      defmodule Order do
       use Ecto.Schema

       @primary_key {:order_id, :id, autogenerate: true}
       schema "order" do
         field(:code, :string)
         field(:total_price, :decimal)
         field(:delivery_date, :utc_datetime)
         field(:metadata, :map)

         has_many :items, Item, foreign_key: :order_id
         belongs_to(:shop, Shop, references: :shop_id)
       end
      end

      defmodule Item do
       use Ecto.Schema

       @primary_key {:item_id, :id, autogenerate: true}
       schema "item" do
         field(:name, :string)
         field(:price, :decimal)
         field(:quantity, :integer)

         belongs_to(:order, Order, references: :order_id)
       end
      end
  """

  @doc ~S"""
  Converts a nested struct to map.
  ## Examples
      order = %Order
      {
        order_id: 1,
        code: "CODE1",
        total_price: Decimal.new(100),
        delivery_date: DateTime.utc_now,
        metadata: %{guest_name: "Hoang Nguyen", is_member: true},
        items: [
          %Item{item_id: 1, name: "Doraemon", price: Decimal.new(20), quantity: 2, order_id: 1},
          %Item{item_id: 2, name: "One Piece", price: Decimal.new(15), quantity: 6, order_id: 1}
        ]
      }
      #=>
      %Order{
        __meta__: #Ecto.Schema.Metadata<:built, "order">,
        code: "CODE1",
        delivery_date: ~U[2021-06-07 09:46:26.549287Z],
        items: [
          %Item{
            __meta__: #Ecto.Schema.Metadata<:built, "item">,
            item_id: nil,
            name: "Doraemon",
            order: #Ecto.Association.NotLoaded<association :order is not loaded>,
            order_id: 1,
            price: #Decimal<20>,
            quantity: 2
          },
          %Item{
            __meta__: #Ecto.Schema.Metadata<:built, "item">,
            item_id: nil,
            name: "One Piece",
            order: #Ecto.Association.NotLoaded<association :order is not loaded>,
            order_id: 1,
            price: #Decimal<15>,
            quantity: 4
          }
        ],
        metadata: %{guest_name: "Hoang Nguyen", is_member: true},
        order_id: 1,
        shop: #Ecto.Association.NotLoaded<association :shop is not loaded>,
        shop_id: nil,
        total_price: #Decimal<100>
      }

      Convertx.map_from_struct(order)
      #=>
      %{
        code: "CODE1",
        delivery_date: ~U[2021-06-07 09:46:26.549287Z],
        items: [
          %{
            item_id: 1,
            name: "Doraemon",
            order_id: 1,
            price: #Decimal<20>,
            quantity: 2
          },
          %{
            item_id: 2,
            name: "One Piece",
            order_id: 1,
            price: #Decimal<15>,
            quantity: 4
          }
        ],
        metadata: %{guest_name: "Hoang Nguyen", is_member: true},
        order_id: 1,
        shop_id: nil,
        total_price: #Decimal<100>
      }

  """
  @spec map_from_struct(struct()) :: map()
  def map_from_struct(%_{__meta__: %{__struct__: _}} = schema) when is_map(schema) do
    schema
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> remove_not_loaded_associations()
    |> map_from_struct()
  end

  def map_from_struct(map) when is_map(map) do
    map
    |> case do
      struct when is_struct(struct) ->
        Map.from_struct(struct)

      map ->
        map
    end
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      value =
        case value do
          %_{__meta__: %{__struct__: _}} ->
            map_from_struct(value)

          %name{} = value when is_struct(value) ->
            Atom.to_string(name)
            |> String.contains?("Schema")
            |> case do
              true ->
                map_from_struct(value)

              _ ->
                value
            end

          value when is_list(value) ->
            value |> Enum.map(&map_from_struct/1)

          _ ->
            value
        end

      Map.put_new(acc, key, value)
    end)
  end

  def map_from_struct(value), do: value

  defp remove_not_loaded_associations(struct) do
    keys_to_remove =
      struct
      |> Enum.filter(fn {_k, v} -> match?(%Ecto.Association.NotLoaded{}, v) end)
      |> Keyword.keys()

    struct
    |> Map.drop(keys_to_remove)
  end
end
