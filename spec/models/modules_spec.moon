import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

factory = require "spec.factory"

import
  Manifests
  Modules
  Users
  Versions
  from require "models"

describe "models.modules", ->
  use_test_env!

  before_each ->
    truncate_tables Manifests, Users, Versions, Modules

  it "should refresh has_dev_version with no dev versions", ->
    mod = factory.Modules!
    mod\update_has_dev_version!
    assert.falsy mod.has_dev_version

  it "should refresh has_dev_version with dev versions", ->
    mod = factory.Modules!
    v = factory.Versions development: true, module_id: mod.id

    mod\update_has_dev_version!
    assert.truthy mod.has_dev_version

  it "allowed_to_edit only retrns true for owner/admin", ->
    mod = factory.Modules!
    assert.falsy mod\allowed_to_edit nil
    assert.truthy mod\allowed_to_edit mod\get_user!
    assert.falsy mod\allowed_to_edit factory.Users!
    assert.truthy mod\allowed_to_edit factory.Users flags: 1

  it "deletes module", ->
    mod = factory.Modules!
    mod\delete!

    user = mod\get_user!
    assert.same -1, user.modules_count

  describe "with storage", ->
    get_log, put_log = {}, {}

    before_each ->
      package.loaded.storage_bucket = {
        get_file: (...) =>
          table.insert get_log, {...}
          "xxx"

        put_file_string: (...) =>
          table.insert put_log, {...}
      }

    after_each ->
      package.loaded.storage_bucket = nil

    it "copies module to user", ->
      mod = factory.Modules name: "alpha"
      v1 = factory.Versions version_name: "1", development: true, module_id: mod.id
      v2 = factory.Versions version_name: "2", module_id: mod.id

      mod2 = factory.Modules name: "beta"
      factory.Versions version_name: "1", module_id: mod2.id

      other_user = factory.Users!

      mod\copy_to_user other_user
      new_mod = unpack other_user\get_modules!
      new_versions = new_mod\get_versions!

      table.sort new_versions, (a, b) -> a.id < b.id

      assert.same {
        {v1.rockspec_key}
        {v2.rockspec_key}
      }, get_log

      expected_puts = for v in *new_versions
        {"xxx", {
          key: v.rockspec_key
          mimetype: "text/x-rockspec"
        }}

      assert.same expected_puts, put_log

      other_user\refresh!
      assert.same 1, other_user.modules_count
