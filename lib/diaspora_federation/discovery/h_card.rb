module DiasporaFederation
  module Discovery
    # This class provides the means of generating an parsing account data to and
    # from the hCard format.
    # hCard is based on +RFC 2426+ (vCard) which got superseded by +RFC 6350+.
    # There is a draft for a new h-card format specification, that makes use of
    # the new vCard standard.
    #
    # @note The current implementation contains a huge amount of legacy elements
    #   and classes, that should be removed and cleaned up in later iterations.
    #
    # @todo This needs some radical restructuring. The generated HTML is not
    #   correctly nested according to the hCard standard and class names are
    #   partially wrong. Also, apart from that, it's just ugly.
    #
    # @example Creating a hCard document from a person hash
    #   hc = HCard.new(
    #     guid:             "0123456789abcdef",
    #     nickname:         "user",
    #     full_name:        "User Name",
    #     seed_url:         "https://server.example/",
    #     photo_large_url:  "https://server.example/uploads/l.jpg",
    #     photo_medium_url: "https://server.example/uploads/m.jpg",
    #     photo_small_url:  "https://server.example/uploads/s.jpg",
    #     public_key:       "-----BEGIN PUBLIC KEY-----\nABCDEF==\n-----END PUBLIC KEY-----",
    #     searchable:       true,
    #     first_name:       "User",
    #     last_name:        "Name"
    #   )
    #   html_string = hc.to_html
    #
    # @example Create a HCard instance from an hCard document
    #   hc = HCard.from_html(html_string)
    #   ...
    #   full_name = hc.full_name
    #   ...
    #
    # @see http://microformats.org/wiki/hCard "hCard 1.0"
    # @see http://microformats.org/wiki/h-card "h-card" (draft)
    # @see http://www.ietf.org/rfc/rfc2426.txt "vCard MIME Directory Profile" (obsolete)
    # @see http://www.ietf.org/rfc/rfc6350.txt "vCard Format Specification"
    class HCard < Entity
      # @!attribute [r] guid
      #   This is just the guid. When a user creates an account on a pod, the pod
      #   MUST assign them a guid - a random hexadecimal string of at least 8
      #   hexadecimal digits.
      #   @return [String] guid
      property :guid

      # @!attribute [r] nickname
      #   the first part of the diaspora handle
      #   @return [String] nickname
      property :nickname

      # @!attribute [r] full_name
      #  @return [String] display name of the user
      property :full_name

      # @!attribute [r] url
      #   @deprecated should be changed to the profile url. The pod url is in
      #     the WebFinger (see {WebFinger#seed_url}, will affect older Diaspora*
      #     installations).
      #
      #   @return [String] link to the pod
      property :url

      # @!attribute [r] public_key
      #   When a user is created on the pod, the pod MUST generate a pgp keypair
      #   for them. This key is used for signing messages. The format is a
      #   DER-encoded PKCS#1 key beginning with the text
      #   "-----BEGIN PUBLIC KEY-----" and ending with "-----END PUBLIC KEY-----".
      #
      #   @note the public key is new in the hcard and is optional now.
      #
      #   @return [String] public key
      property :public_key, default: nil

      # @!attribute [r] photo_large_url
      #   @return [String] url to the big avatar (300x300)
      property :photo_large_url
      # @!attribute [r] photo_medium_url
      #   @return [String] url to the medium avatar (100x100)
      property :photo_medium_url
      # @!attribute [r] photo_small_url
      #   @return [String] url to the small avatar (50x50)
      property :photo_small_url

      # @!attribute [r] first_name
      #   @deprecated We decided to only use one name field, these should be removed
      #     in later iterations (will affect older Diaspora* installations).
      #
      #   @see #full_name
      #   @return [String] first name
      property :first_name

      # @!attribute [r] last_name
      #   @deprecated We decided to only use one name field, these should be removed
      #     in later iterations (will affect older Diaspora* installations).
      #
      #   @see #full_name
      #   @return [String] last name
      property :last_name

      # @!attribute [r] searchable
      #   @deprecated As this is a simple property, consider move to WebFinger instead
      #     of HCard. vCard has no comparable field for this information, but
      #     Webfinger may declare arbitrary properties (will affect older Diaspora*
      #     installations).
      #
      #   flag if a user is searchable by name
      #   @return [Boolean] searchable flag
      property :searchable

      # CSS selectors for finding all the hCard fields
      SELECTORS = {
        uid:          ".uid",
        nickname:     ".nickname",
        fn:           ".fn",
        given_name:   ".given_name",
        family_name:  ".family_name",
        url:          "#pod_location[href]",
        photo:        ".entity_photo .photo[src]",
        photo_medium: ".entity_photo_medium .photo[src]",
        photo_small:  ".entity_photo_small .photo[src]",
        key:          ".key",
        searchable:   ".searchable"
      }

      # Create the HTML string from the current HCard instance
      # @return [String] HTML string
      def to_html
        builder = create_builder

        content = builder.doc.at_css("#content_inner")

        add_simple_property(content, :uid, "uid", @guid)
        add_simple_property(content, :nickname, "nickname", @nickname)
        add_simple_property(content, :full_name, "fn", @full_name)
        add_simple_property(content, :searchable, "searchable", @searchable)

        add_property(content, :key) do |html|
          html.pre(@public_key.to_s, class: "key")
        end

        # TODO: remove me!  ###################
        add_simple_property(content, :first_name, "given_name", @first_name)
        add_simple_property(content, :family_name, "family_name", @last_name)
        #######################################

        add_property(content, :url) do |html|
          html.a(@url.to_s, id: "pod_location", class: "url", rel: "me", href: @url.to_s)
        end

        add_photos(content)

        builder.doc.to_xhtml(indent: 2, indent_text: " ")
      end

      # Creates a new HCard instance from the given HTML string.
      # @param html_string [String] HTML string
      # @return [HCard] HCard instance
      # @raise [InvalidData] if the HTML string is invalid or incomplete
      def self.from_html(html_string)
        doc = parse_html_and_validate(html_string)

        data = {
          guid:             guid_from_doc(doc),
          nickname:         content_from_doc(doc, :nickname),
          full_name:        content_from_doc(doc, :fn),
          url:              element_from_doc(doc, :url)["href"],
          photo_large_url:  photo_from_doc(doc, :photo),
          photo_medium_url: photo_from_doc(doc, :photo_medium),
          photo_small_url:  photo_from_doc(doc, :photo_small),
          searchable:       (content_from_doc(doc, :searchable) == "true"),

          # TODO: remove me!  ###################
          first_name:       content_from_doc(doc, :given_name),
          last_name:        content_from_doc(doc, :family_name)
          #######################################
        }
        # TODO: public key is new and can be missing
        data[:public_key] = content_from_doc(doc, :key) unless element_from_doc(doc, :key).nil?
        new(data)
      end

      private

      # Creates the base HCard html structure
      # @return [Nokogiri::HTML::Builder] HTML Builder instance
      def create_builder
        Nokogiri::HTML::Builder.new do |html|
          html.html {
            html.head {
              html.meta(charset: "UTF-8")
              html.title(@full_name)
            }

            html.body {
              html.div(id: "content") {
                html.h1(@full_name)
                html.div(id: "content_inner", class: "entity_profile vcard author") {
                  html.h2("User profile")
                }
              }
            }
          }
        end
      end

      # Add a property to the hCard document. The element will be added to the given
      # container element and a "definition list" structure will be created around
      # it. A Nokogiri::HTML::Builder instance will be passed to the given block,
      # which should be used to add the element(s) containing the property data.
      #
      # @param container [Nokogiri::XML::Element] parent element for added property HTML
      # @param name [Symbol] property name
      # @param block [Proc] block returning an element
      def add_property(container, name, &block)
        Nokogiri::HTML::Builder.with(container) do |html|
          html.dl(class: "entity_#{name}") {
            html.dt(name.to_s.capitalize)
            html.dd {
              block.call(html)
            }
          }
        end
      end

      # Calls {HCard#add_property} for a simple text property.
      # @param container [Nokogiri::XML::Element] parent element
      # @param name [Symbol] property name
      # @param class_name [String] HTML class name
      # @param value [#to_s] property value
      # @see HCard#add_property
      def add_simple_property(container, name, class_name, value)
        add_property(container, name) do |html|
          html.span(value.to_s, class: class_name)
        end
      end

      # Calls {HCard#add_property} to add the photos
      # @param container [Nokogiri::XML::Element] parent element
      # @see HCard#add_property
      def add_photos(container)
        add_property(container, :photo) do |html|
          html.img(class: "photo avatar", width: "300", height: "300", src: @photo_large_url.to_s)
        end

        add_property(container, :photo_medium) do |html|
          html.img(class: "photo avatar", width: "100", height: "100", src: @photo_medium_url.to_s)
        end

        add_property(container, :photo_small) do |html|
          html.img(class: "photo avatar", width: "50", height: "50", src: @photo_small_url.to_s)
        end
      end

      # Make sure some of the most important elements are present in the parsed
      # HTML document.
      # @param [LibXML::XML::Document] doc HTML document
      # @return [Boolean] validation result
      def self.html_document_complete?(doc)
        !(doc.at_css(SELECTORS[:fn]).nil? || doc.at_css(SELECTORS[:nickname]).nil? ||
          doc.at_css(SELECTORS[:url]).nil? || doc.at_css(SELECTORS[:photo]).nil?)
      end
      private_class_method :html_document_complete?

      def self.parse_html_and_validate(html_string)
        raise ArgumentError, "hcard html is not a string" unless html_string.instance_of?(String)

        doc = Nokogiri::HTML::Document.parse(html_string)
        raise InvalidData, "hcard html incomplete" unless html_document_complete?(doc)
        doc
      end
      private_class_method :parse_html_and_validate

      def self.element_from_doc(doc, selector)
        doc.at_css(SELECTORS[selector])
      end
      private_class_method :element_from_doc

      def self.content_from_doc(doc, content_selector)
        element_from_doc(doc, content_selector).content
      end
      private_class_method :content_from_doc

      def self.photo_from_doc(doc, photo_selector)
        element_from_doc(doc, photo_selector)["src"]
      end
      private_class_method :photo_from_doc

      # @deprecated hack for old hcard
      # @todo remove this when all pods have the new generator
      def self.guid_from_doc(doc)
        uid_element = element_from_doc(doc, :uid)
        uid_element.content unless uid_element[:class].include? "nickname"
      end
      private_class_method :guid_from_doc
    end
  end
end
