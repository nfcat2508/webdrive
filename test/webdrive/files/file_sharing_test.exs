defmodule Webdrive.FileSharingTest do
  use Webdrive.DataCase, async: false

  import Webdrive.FilesFixtures

  alias Ecto.Changeset
  alias Webdrive.Files.FileSharing

  @some_valid_secret "abcdABCD1234"

  describe "validation:" do
    setup do
      [file_sharing: prepare_file_sharing()]
    end

    test "owner is required", %{file_sharing: file_sharing} do
      attr = prepare_file_sharing_attrs()
      no_owner = Map.put(file_sharing, :owner, nil)
      empty_owner = Map.put(file_sharing, :owner, "")
      space_owner = Map.put(file_sharing, :owner, " ")

      assert has_error?(FileSharing.changeset(no_owner, attr))
      assert has_error?(FileSharing.changeset(empty_owner, attr))
      assert has_error?(FileSharing.changeset(space_owner, attr))
    end

    test "secret is required", %{file_sharing: file_sharing} do
      no_secret = Map.put(file_sharing, :secret, nil)

      assert has_error?(FileSharing.changeset(no_secret, %{}))
      assert has_error?(FileSharing.changeset(file_sharing, %{secret: ""}))
      assert has_error?(FileSharing.changeset(file_sharing, %{secret: " "}))
    end

    test "secret min length is 12", %{file_sharing: file_sharing} do
      min_secret = "abcdABCD1234"
      too_short_secret = String.slice(min_secret, 1, 11)

      assert has_error?(FileSharing.changeset(file_sharing, %{secret: too_short_secret}))
      assert no_error?(FileSharing.changeset(file_sharing, %{secret: min_secret}))
    end

    test "secret max length is 72", %{file_sharing: file_sharing} do
      max_secret = String.duplicate("abcABC123", 8)
      too_long_secret = max_secret <> "x"

      assert has_error?(FileSharing.changeset(file_sharing, %{secret: too_long_secret}))
      assert no_error?(FileSharing.changeset(file_sharing, %{secret: max_secret}))
    end

    # since argon2 is compute intense, we want to limit the byte size
    test "secret max byte size is 72", %{file_sharing: file_sharing} do
      # "ö" requires two bytes
      max_secret = "abcdABCD1234" <> String.duplicate("ö", 30)
      # has String length == 43 but byte size 73
      too_long_secret = max_secret <> "x"

      assert has_error?(FileSharing.changeset(file_sharing, %{secret: too_long_secret}))
      assert no_error?(FileSharing.changeset(file_sharing, %{secret: max_secret}))
    end

    test "secret must contain a lowercase character", %{file_sharing: file_sharing} do
      invalid_secret = "ABCDABCD1234"
      valid_secret = "ABCDABCd1234"

      assert has_error?(FileSharing.changeset(file_sharing, %{secret: invalid_secret}))
      assert no_error?(FileSharing.changeset(file_sharing, %{secret: valid_secret}))
    end

    test "secret must contain an uppercase character", %{file_sharing: file_sharing} do
      invalid_secret = "abcdabcd1234"
      valid_secret = "abcdabcD1234"

      assert has_error?(FileSharing.changeset(file_sharing, %{secret: invalid_secret}))
      assert no_error?(FileSharing.changeset(file_sharing, %{secret: valid_secret}))
    end

    test "secret must contain a digit or punctuation character", %{file_sharing: file_sharing} do
      invalid_secret = "abcdABCDabcd"
      valid_secret1 = "abcdABCDabc1"
      valid_secret2 = "abcdABCDabc!"

      assert has_error?(FileSharing.changeset(file_sharing, %{secret: invalid_secret}))
      assert no_error?(FileSharing.changeset(file_sharing, %{secret: valid_secret1}))
      assert no_error?(FileSharing.changeset(file_sharing, %{secret: valid_secret2}))
    end

    test "upload_id is required", %{file_sharing: file_sharing} do
      no_upload_id = Map.put(file_sharing, :upload_id, nil)

      assert has_error?(FileSharing.changeset(no_upload_id, %{}))
      assert has_error?(FileSharing.changeset(file_sharing, %{upload_id: ""}))
      assert has_error?(FileSharing.changeset(file_sharing, %{upload_id: " "}))
    end

    test "upload_id must be an UUID", %{file_sharing: file_sharing} do
      assert has_error?(FileSharing.changeset(file_sharing, %{upload_id: "abc"}))
      assert has_error?(FileSharing.changeset(file_sharing, %{upload_id: 17.23}))
    end
  end

  test "when changeset is created, the given password is replaced by an argon2 hash" do
    attrs = prepare_file_sharing_attrs(%{secret: @some_valid_secret})

    actual_secret =
      FileSharing.changeset(prepare_file_sharing(), attrs)
      |> get_change(:secret)

    assert actual_secret =~ ~r/^\$argon2.*\$v=.*\$m=.*,t=.*p=.*\$.*\$.*/
  end

  test "when changeset is created, an identifier pair (hash + base64 url-encoded) is added" do
    attrs = prepare_file_sharing_attrs()

    actual = FileSharing.changeset(prepare_file_sharing(), attrs)
    actual_identifier = get_change(actual, :identifier)
    actual_identifier_user_param = get_change(actual, :identifier_user_param)

    # the identifier-pair is matching
    assert FileSharing.decode_identifier(actual_identifier_user_param) == actual_identifier
  end

  test "secret is valid if hash of provided secret matches stored hash" do
    hashed_secret = get_hash_for(@some_valid_secret)
    file_sharing_with_hashed_secret = prepare_file_sharing(%{secret: hashed_secret})

    assert FileSharing.valid_secret?(file_sharing_with_hashed_secret, @some_valid_secret)
  end

  test "secret is not valid if hash of provided secret does not match stored hash" do
    hashed_secret = get_hash_for(@some_valid_secret)
    file_sharing_with_hashed_secret = prepare_file_sharing(%{secret: hashed_secret})

    refute FileSharing.valid_secret?(file_sharing_with_hashed_secret, "incorrect_secret")
  end

  test "decoding the identifier_user_param returns error, if provided value is not a String" do
    assert FileSharing.decode_identifier(17) == :error
  end

  test "decoding the identifier_user_param returns error, if provided String is not base64 url-encoded" do
    assert FileSharing.decode_identifier("notBase64") == :error
  end

  defp get_hash_for(value) do
    FileSharing.changeset(prepare_file_sharing(), %{secret: value})
    |> get_change(:secret)
  end

  defp has_error?(actual_changeset) do
    refute actual_changeset.valid?
    assert %Changeset{errors: [_ | _]} = actual_changeset
  end

  defp no_error?(actual_changeset) do
    assert %Changeset{errors: []} = actual_changeset
  end
end
