module Agents
  class LndNodeInfoAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule '1h'

    description do
      <<-MD
      The Github notification agent fetches notifications and creates an event by notification.

      `mark_as_read` is used to post request for mark as read notification.

      `result_limit` is used when you want to limit result per page.

      `real_value` is used for calculating token value with the tokenDecimal applied.

      `with_confirmations` is used to avoid an event as soon as it increases.

      `type` can be tokentx type (you can see api documentation).
      Get a list of "ERC20 - Token Transfer Events" by Address

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:
      {
          "version": {
            "version": "0.11.0-beta commit=",
            "commit_hash": "",
            "identity_pubkey": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
            "alias": "XXXXXXXXXXX",
            "color": "XXXXXXX",
            "num_pending_channels": 0,
            "num_active_channels": 5,
            "num_inactive_channels": 0,
            "num_peers": 5,
            "block_height": 644844,
            "block_hash": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
            "best_header_timestamp": "1598100386",
            "synced_to_chain": true,
            "synced_to_graph": true,
            "testnet": false,
            "chains": [
              {
                "chain": "bitcoin",
                "network": "mainnet"
              }
            ],
            "uris": [
              "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
            ],
            "features": {
              "0": {
                "name": "data-loss-protect",
                "is_required": true,
                "is_known": true
              },
              "5": {
                "name": "upfront-shutdown-script",
                "is_required": false,
                "is_known": true
              },
              "7": {
                "name": "gossip-queries",
                "is_required": false,
                "is_known": true
              },
              "9": {
                "name": "tlv-onion",
                "is_required": false,
                "is_known": true
              },
              "13": {
                "name": "static-remote-key",
                "is_required": false,
                "is_known": true
              },
              "15": {
                "name": "payment-addr",
                "is_required": false,
                "is_known": true
              },
              "17": {
                "name": "multi-path-payments",
                "is_required": false,
                "is_known": true
              }
            }
          }
        }
    MD

    def default_options
      {
        'url' => '',
        'changes_only' => 'true',
        'expected_receive_period_in_days' => '2',
        'macaroon' => '',
      }
    end

    form_configurable :url, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :macaroon, type: :string
    form_configurable :expected_receive_period_in_days, type: :string

    def validate_options
      unless options['url'].present?
        errors.add(:base, "url is a required field")
      end

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      unless options['macaroon'].present?
        errors.add(:base, "macaroon is a required field")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      fetch
    end

    private

    def fetch
      uri = URI.parse("#{interpolated['url']}/v1/getinfo")
      request = Net::HTTP::Get.new(uri)
      request["Grpc-Metadata-Macaroon"] = "#{interpolated['macaroon']}"
      
      req_options = {
        use_ssl: uri.scheme == "https",
        verify_mode: OpenSSL::SSL::VERIFY_NONE,
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log "request  status : #{response.code}"

      payload_ori = JSON.parse(response.body)
      payload = JSON.parse(response.body)

      if interpolated['changes_only'] == 'true'
        if payload.to_s != memory['last_status']
          if "#{memory['last_status']}" == ''
              create_event payload: payload
          else
            last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil", ": null")
            last_status = JSON.parse(last_status)
            found = false
            if payload['num_active_channels'] != last_status['num_active_channels']
              payload[:num_active_channels_changed] = true
              found = true
              log "number of active channels changed"
            end
            if payload['num_inactive_channels'] != last_status['num_inactive_channels']
              payload[:num_inactive_channels_changed] = true
              found = true
              log "number of inactive channels changed"
            end
            if payload['version'] != last_status['version']
              payload[:version_changed] = true
              found = true
              log "version changed"
            end
            if payload['identity_pubkey'] != last_status['identity_pubkey']
              payload[:identity_pubkey_changed] = true
              log "identity pubkey changed"
              found = true
            end
            if found == true
                create_event payload: payload
            end
          end
          memory['last_status'] = payload_ori.to_s
        end
      else
        create_event payload: payload
        if payload.to_s != memory['last_status']
          memory['last_status'] = payload_ori.to_s
        end
      end
    end
  end
end
