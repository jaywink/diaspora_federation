require "diaspora_federation/web_finger"

# configure the federation engine
DiasporaFederation.configure do |config|
  # the pod url
  config.server_uri = URI("http://localhost:3000/")

  config.define_callbacks do
    on :person_webfinger_fetch do |handle|
      person = Person.find_by(diaspora_handle: handle)
      if person
        DiasporaFederation::WebFinger::WebFinger.new(
          acct_uri:    "acct:#{person.diaspora_handle}",
          alias_url:   person.alias_url,
          hcard_url:   person.hcard_url,
          seed_url:    person.url,
          profile_url: person.profile_url,
          atom_url:    person.atom_url,
          salmon_url:  person.salmon_url,
          guid:        person.guid,
          public_key:  person.serialized_public_key
        )
      end
    end

    on :person_hcard_fetch do |guid|
      person = Person.find_by(guid: guid)
      if person
        DiasporaFederation::WebFinger::HCard.new(
          guid:             person.guid,
          nickname:         person.nickname,
          full_name:        person.full_name,
          url:              person.url,
          photo_large_url:  person.photo_default_url,
          photo_medium_url: person.photo_default_url,
          photo_small_url:  person.photo_default_url,
          public_key:       person.serialized_public_key,
          searchable:       person.searchable,
          first_name:       person.first_name,
          last_name:        person.last_name
        )
      end
    end
  end
end
