defmodule Webdrive.Files.UploadRequestTest do
  use Webdrive.DataCase, async: false

  alias Webdrive.Files.UploadRequest

  describe "validation:" do
    test "valid, if UUID provided" do
      given = %{id: Ecto.UUID.generate()}

      actual = UploadRequest.changeset(given)

      assert actual.valid?
    end

    test "id is required" do
      given = %{id: nil}
      actual = UploadRequest.changeset(given)
      refute actual.valid?

      given = %{id: " "}
      actual = UploadRequest.changeset(given)
      refute actual.valid?
    end

    test "invalid, if id not UUID" do
      given = %{id: 128}
      actual = UploadRequest.changeset(given)
      refute actual.valid?

      given = %{id: "128"}
      actual = UploadRequest.changeset(given)
      refute actual.valid?
    end
  end
end
