defmodule Gringotts.Gateways.SagePay do
  @moduledoc """
  [SagePay][home] gateway implementation.

  --------------------------------------------------------------------------------

  Most `Gringotts` API calls accept an optional `Keyword` list `opts` to supply
  optional arguments for transactions with the gateway.

  The following features of SagePay are implemented:

  | Action                       | Method        | 
  | ------                       | ------        | 
  | Authorize                    | `authorize/3` | 
  | Release                      | `capture/3`   | 
  | Refund                       | `refund/3`    | 
  | Reversal                     | `void/2`      | 
  | Purchase                     | `purchase/3`  | 

  [home]: http://sagepay.co.uk
  [docs]: integrations.sagepay.co.uk

  ## The `opts` argument

  Most `Gringotts` API calls accept an optional `keyword` list `opts` to supply
  optional arguments for transactions with the SagePay gateway. 

  The following keys are supported:

  |  Key                   |  Remarks                                                                    |
  |  ---                   |  -------                                                                    |
  |  `auth_id`             |  A unique merchant id provided by the merchant.                             |
  |  `vendor`              |  Name of the merchant.                                                      |
  |  `vendor_tx_code`      |  vendor_tx_code is a unique code for every transaction in SagePay.          |
  |  `transaction_type`    |  SagePay allows four transactions type:- Deferred, Payment, Repeat, Refund. |
  |  `first_name`          |  First name of a customer.                                                  |
  |  `last_name`           |  Last name of a customer.                                                   |
  |  `address`             |  Billing address of a customer.                                             |

  ## Registering your SagePay account at `Gringotts`

  After [making an account on SagePay][dashboard], provide your `:auth_id` and 
  `:merchant_name` in Application config.

  Here's how the secrets map to the required configuration parameters for SagePay:

  | Config parameter        | SagePay secret         |
  | ------------------------| -----------------------|
  | `:auth_id`              | **Authorization Id**   |
  | `:merchant_name`        | **Name of a merchant** |

  Your Application config **must include the `:auth_id`, `:merchant_name`
  fields** and would look something like this:

      config :gringotts, Gringotts.Gateways.SagePay,
        auth_id: "your_secret_user_id",
        merchant_name: "name_of_merchant"
        
  [dashboard]: https://applications.sagepay.com/apply

  ## Scope of this module

  * SagePay does not process money in cents, and the `amount` is converted to integer.
  * SagePay supports payments from various cards and banks.

  ## Supported currencies and countries

      AUD, CAD, CHF, CYP, DKK, EUR, GBP, HKD, INR, JPY, 
      MTL, NOK, NZD, RUB, SEK, SGD, THB, TRY, USD, ZAR 

  ## Following the examples

  1. First, set up a sample application and configure it to work with SagePay.
  - You could do that from scratch by following our [Getting Started][gs] guide.
      - To save you time, we recommend [cloning our example
      repo][example] that gives you a pre-configured sample app ready-to-go.
          + You could use the same config or update it the with your "secrets"
          as described [above](#module-registering-your-sagepay-account-at-gringotts).

  2. To save a lot of time, create a [`.iex.exs`][iex-docs] file as shown in
     [link][sagepay.iex.exs] to introduce a set of handy bindings and
     aliases.

  We'll be using these in the examples below.
  [gs]: file:///home/anwar/gringotts/doc/Gringotts.Gateways.SagePay.html#
  [example]: https://github.com/aviabird/gringotts_example
  [iex-docs]: https://hexdocs.pm/iex/IEx.html#module-the-iex-exs-file
  [sagepay.iex.exs]: https://github.com/Anwar0902/graph/blob/master/sagepay.iex.exs
  """

  # The Base module has the (abstract) public API, and some utility
  # implementations.
  use Gringotts.Gateways.Base

  # The Adapter module provides the `validate_config/1`
  # Add the keys that must be present in the Application config in the
  # `required_config` list
  use Gringotts.Adapter, required_config: []
  alias Gringotts.{Money, CreditCard, Response}
  @url "https://pi-test.sagepay.com/api/v1/"

  # SagePay supports payment only by providing Merchant `:auth_id` and `:merchant_name`
  # which generates `merchant_session_key` and then providing card details generates
  # `card_identifier` which is required for authorization.

  @doc """
  Performs a (pre) Authorize operation.

  The authorization validates the `card` details with the banking network,
  places a hold on the transaction `amount` in the customer’s issuing bank.

  SagePay returns an transaction ID(available in `Response.id`) string which can be used to:
  * `capture/3` an amount.
  * `void/2` abort deferred transaction.
  * `refund/3` an amount.

  ## Note

  * The `merchant_session_key` expires after 400 seconds and can only be used to create one successful `card_identifier`. 
  * It will also expire and will be removed after 3 failed attempts to create a `card_identifier`.
  * `vendor_tx_code` in opts should always be unique.
  * `address` should be provided as defined in `Gringotts.address`.

  ## Example

  The following example shows how one would (pre) authorize a payment of 42£ on
  a sample `card`.

      iex> amount = Money.new(42, :GBP)
      iex> address = %Address{ street1: "407 St.", street2: "John Street", city: "London", postal_code: "EC1V 4AB", country: "GB"} 
      iex> card = %Gringotts.CreditCard{number: "4929000005559",month: 3,year: 20,first_name: "SAM",last_name: "JONES",verification_code: "123",brand: "VISA"}
      iex> opts = [
                  config: %{
                      auth_id: "aEpZeHN3N0hMYmo0MGNCOHVkRVM4Q0RSRkxodUo4RzU0TzZyRHBVWHZFNmhZRHJyaWE6bzJpSFNyRnliWU1acG1XT1FNdWhzWFA1MlY0ZkJ0cHVTRHNocktEU1dzQlkxT2lONmh3ZDlLYjEyejRqNVVzNXU=",
                      merchant_name: "sandbox"
                  },
                  transaction_type: "Deferred",
                  vendor_tx_code: "demotransaction-51",
                  description: "Demo Payment",
                  customer_first_name: "Sam",
                  customer_last_name: "Jones",
                  billing_address: %{
                                      "address1": "407 St. John Street",
                                      "city": "London",
                                      "postalCode": "EC1V 4AB",
                                      "country": "GB"
                                    }
            ]
      iex> {:ok, auth_result} = Gringotts.authorize(Gringotts.Gateways.SagePay, amount, card, opts)
      iex> auth_result.id
  """
  @spec authorize(Money.t(), CreditCard.t(), keyword) :: {:ok | :error, Response.t()}
  def authorize(amount, %CreditCard{} = card, opts) do
    merchant_key = generate_merchant_key(opts)

    card = card_params(card)
    card_identifier = generate_card_identifier(card, merchant_key)

    transaction_params = transaction_details(amount, merchant_key, card_identifier, opts)

    transaction_header = [
      {"Authorization", "Basic " <> opts[:config].auth_id},
      {"Content-type", "application/json"}
    ]

    commit(:post, "transactions", transaction_params, transaction_header)
  end

  @doc """

  `amount` is transferred to the merchants's account by using transaction Id (`payement_id`)
   generated in `authorize/3` function by SagePay.

  ## Note

  * Deferred transactions are not sent to the bank for completion until you capture them using the capture instruction.
  * You can release only once and only for an amount up to and including the amount of the original Deferred transaction.

  ## Example

  The following example shows how one would capture a previously authorized amount worth 100£ by
  referencing the obtained transaction ID (payment_id) from `authorize/3` function.

      iex> amount = Money.new(100, :GBP)
      iex> {:ok, auth_result} = Gringotts.authorize(Gringotts.Gateways.SagePay, amount, card, opts)
      iex> {:ok, capture_result} = Gringotts.capture(Gringotts.Gateways.SagePay, auth_result.id, amount, opts)

  """
  @spec capture(String.t(), Money.t(), keyword) :: {:ok | :error, Response.t()}
  def capture(payment_id, amount, opts) do
    {currency, value} = Money.to_string(amount)

    capture_header = [
      {"Authorization", "Basic " <> opts[:config].auth_id},
      {"Content-type", "application/json"}
    ]

    capture_body =
      Poison.encode!(%{
        "instructionType" => opts[:transaction_type],
        "amount" => Kernel.trunc(String.to_float(value))
      })

    endpoint = "transactions/" <> payment_id <> "/instructions"

    commit(:post, endpoint, capture_body, capture_header)
  end

  @doc """
  Transfers `amount` from the customer to the merchant.

  SagePay attempts to process a purchase on behalf of the customer, by
  debiting `amount` from the customer's account by charging the customer's
  `card`.

  ## Note

  * In SagePay we have to explicitly call the `authorize/3` function and the
    `capture/3` function in purchase to complete the transaction. 

  ## Example

      iex> amount = Money.new(100, :GBP)
      iex> Gringotts.purchase(Gringotts.Gateways.SagePay, amount, card, opts)

  """
  @spec purchase(Money.t(), CreditCard.t(), keyword) :: {:ok | :error, Response.t()}
  def purchase(amount, card, opts) do
    {:ok, response} = authorize(amount, card, opts)
    opts = List.keyreplace(opts, :transaction_type, 0, {:transaction_type, "release"})
    capture(response.id, amount, opts)
  end

  ###############################################################################
  #                                PRIVATE METHODS                              #
  ###############################################################################

  # Makes the request to sagepay's network.
  # For consistency with other gateway implementations, make your (final)
  # network request in here, and parse it using another private method called
  # `respond`.

  # @spec commit(_) :: {:ok | :error, Response}
  defp commit(:post, endpoint, params, opts) do
    a_url = @url <> endpoint

    a_url
    |> HTTPoison.post(params, opts)
    |> respond
  end

  defp format_response(:post, endpoint, params, opts) do
    a_url = @url <> endpoint

    response = HTTPoison.post(a_url, params, opts)

    case response do
      {:ok, %HTTPoison.Response{body: body}} -> {:ok, body |> Poison.decode!()}
      _ -> %{"error" => "something went wrong, please try again later"}
    end
  end

  # Function `generate_merchant_key` generate a `merchant_session_key` that will exist only for 400
  # seconds and for 3 wrong `card_identifiers`.

  defp generate_merchant_key(opts) do
    merchant_body = Poison.encode!(%{vendorName: opts[:config].merchant_name})

    merchant_header = [
      {"Authorization", "Basic " <> opts[:config].auth_id},
      {"Content-type", "application/json"}
    ]

    {:ok, merchant_key} =
      format_response(:post, "merchant-session-keys", merchant_body, merchant_header)

    merchant_key
    |> Map.get("merchantSessionKey")
  end

  # `card_params` returns credit card details of a customer from `Gringotts.Creditcard`.

  defp card_params(card) do
    expiry_date = card.month * 100 + card.year

    %{
      "cardDetails" => %{
        "cardholderName" => CreditCard.full_name(card),
        "cardNumber" => card.number,
        "expiryDate" =>
          expiry_date
          |> Integer.to_string()
          |> String.pad_leading(4, "0"),
        "securityCode" => card.verification_code
      }
    }
  end

  # Function `generate_card_identifier` generate a unique `card_identifier` for every transaction.

  defp generate_card_identifier(card, merchant_key) do
    card_header = [
      {"Authorization", "Bearer " <> merchant_key},
      {"Content-type", "application/json"}
    ]

    card = card |> Poison.encode!()

    {:ok, card_identifier} = format_response(:post, "card-identifiers", card, card_header)

    card_identifier
    |> Map.get("cardIdentifier")
  end

  # Function `transaction_details` creates the actual body (details of the customer )of the card
  # and with `merchant_session_key`, `card_identifier` ,shipping address of a customer, and
  # other details and converting the map into keyword list.

  defp transaction_details(amount, merchant_key, card_identifier, opts) do
    {currency, value} = Money.to_string(amount)
    full_address = opts[:billing_address].street1 <> " " <> opts[:billing_address].street2

    Poison.encode!(%{
      "transactionType" => opts[:transaction_type],
      "paymentMethod" => %{
        "card" => %{
          "merchantSessionKey" => merchant_key,
          "cardIdentifier" => card_identifier,
          "save" => true
        }
      },
      "vendorTxCode" => opts[:vendor_tx_code],
      "amount" => Kernel.trunc(String.to_float(value)),
      "currency" => currency,
      "description" => opts[:description],
      "customerFirstName" => opts[:customer_first_name],
      "customerLastName" => opts[:customer_last_name],
      "billingAddress" => %{
        "address1" => full_address,
        "city" => opts[:billing_address].city,
        "postalCode" => opts[:billing_address].postal_code,
        "country" => opts[:billing_address].country
      }
    })
  end

  # Parses sagepay's response and returns a `Gringotts.Response` struct
  # in a `:ok`, `:error` tuple.

  @spec respond(term) :: {:ok | :error, Response}

  defp respond({:ok, %{status_code: 201, body: body}}) do
    response_body = body |> Poison.decode!()

    {:ok,
     %Response{
       success: true,
       id: response_body["transactionId"],
       status_code: 201,
       message: response_body["statusDetail"],
       raw: body
     }}
  end

  defp respond({:ok, %{status_code: status_code, body: body}}) do
    response_body = body |> Poison.decode!()

    {:error,
     %Response{
       success: false,
       id: response_body["transactionId"],
       status_code: status_code,
       message: response_body["statusDetail"],
       raw: body
     }}
  end

  defp respond({:error, %HTTPoison.Error{} = error}) do
    {
      :error,
      Response.error(
        reason: "network related failure",
        message: "HTTPoison says '#{error.reason}' [ID: #{error.id || "nil"}]"
      )
    }
  end
end