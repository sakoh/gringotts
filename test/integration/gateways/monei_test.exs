defmodule Kuber.Hex.Integration.Gateways.MoneiTest do
  use ExUnit.Case, async: false

  alias Kuber.Hex.{
    CreditCard,
    Worker
  }
  alias Kuber.Hex.Gateways.Monei, as: Gateway

  @moduletag :integration
  
  @card %CreditCard{
    first_name: "Jo",
    last_name: "Doe",
    number: "4200000000000000",
    year: 2099,
    month: 12,
    verification_code:  "123",
    brand: "VISA"
  }

  setup_all do
    auth = %{userId: "8a8294186003c900016010a285582e0a", password: "hMkqf2qbWf", entityId: "8a82941760036820016010a28a8337f6"}
    Application.put_env(:kuber_hex, Kuber.Hex.Gateways.Monei, [adapter: Kuber.Hex.Gateways.Monei,
                                                               userId: "8a8294186003c900016010a285582e0a",
                                                               password: "hMkqf2qbWf",
                                                               entityId: "8a82941760036820016010a28a8337f6"])
  end

  test "authorize." do
    case Kuber.Hex.authorize(:payment_worker, Gateway, 3.1, @card) do
      {:ok, response} ->
        assert response.code == "000.100.110"
        assert response.description == "Request successfully processed in 'Merchant in Integrator Test Mode'"
        assert String.length(response.id) == 32
      {:error, _err} -> flunk()
    end
  end

  @tag :skip
  test "capture." do
    case Kuber.Hex.capture(:payment_worker, Gateway, 32.00, "s") do
      {:ok, response} ->
        assert response.code == "000.100.110"
        assert response.description == "Request successfully processed in 'Merchant in Integrator Test Mode'"
        assert String.length(response.id) == 32
        
      {:error, _err} -> flunk()
    end
  end

  test "purchase." do
    case Kuber.Hex.purchase(:payment_worker, Gateway, 32, @card) do
      {:ok, response} ->
        assert response.code == "000.100.110"
        assert response.description == "Request successfully processed in 'Merchant in Integrator Test Mode'"
        assert String.length(response.id) == 32
      {:error, _err} -> flunk()
    end
  end

  test "Environment setup" do
    config = Application.get_env(:kuber_hex, Kuber.Hex.Gateways.Monei)
    assert config[:adapter] == Kuber.Hex.Gateways.Monei
  end

end
