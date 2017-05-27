require "tomato/api/version"
require "net/http"
require "json"

module Tomato
  class API
    attr_accessor :session_id, :host, :user, :pass

    def initialize(host, user: 'root', pass: nil, session_id: nil)
      @host = host
      @user = user
      @pass = pass
      @session_id = session_id
    end

    def devices
      ret = post('devlist')
      device_map = Hash.new { |h, k| h[k] = Device.new }
      ret['arplist'].each do |d|
        ip, mac, interface = *d

        dev = device_map[mac]
        dev.mac = mac
        dev.ip = ip
        dev.interface = interface
      end

      ret['dhcpd_lease'].each do |d|
        name, ip, mac, expires_in = *d

        dev = device_map[mac]
        dev.mac = mac
        dev.name = name
        dev.lease_expires_in = expires_in
        dev.ip = ip

      end
      device_map
    end

    IPTRAFFIC_ATTRIBUTES = [
      :rx,
      :tx,
      :tcpi,
      :tcpo,
      :udpi,
      :udpo,
      :icmpi,
      :icmpo,
      :tcpconn,
      :udpconn,
    ]
    def iptraffic
      initial = Hash[post('iptraffic')['iptraffic'].map do |data|
        [data.shift, Hash[IPTRAFFIC_ATTRIBUTES.zip(data)]]
      end]
    end

    private

    def http
      @http ||= Net::HTTP.new(host)
    end

    def req(request)
      http.request(request)
    end

    def session_id
      @session_id ||= begin
        req = Net::HTTP::Get.new('/')
        req.basic_auth(user, pass)
        http.request(req).body.match(/(TID[a-f0-9]+)/)[1]
      end
    end

    def post(exec)
      @post_req ||= begin
        r = Net::HTTP::Post.new('/update.cgi')
        r.basic_auth(user, pass)
        r
      end

      @post_req.set_form_data({'exec' => exec,
                              '_http_id' => session_id})

      res = req(@post_req)
      str = res.body

      data = {}
      str.split(/\n+/).reject { |l| l.strip == '' }.each do |line|
        key = line.match(/^(\w+)\s*=/)[1]
        next if key == 'dhcpd_static' # this includes JS for split.
        line = line.sub(/^(\w+)\s*=\s*/, '').sub(/;\n*\Z/, '')

        json = line.gsub(/'([^']+?)':/, '"\1":').gsub(/'/, '"')
        data[key] = JSON.parse(json.gsub(/\b0x([0-9a-f]+)/) { |hex| hex.to_i(16) })
      end

      data
    end
  end

  class Device
    attr_accessor :name, :ip, :mac, :lease_expires_in, :interface

    def lease_expires_in=(data)
      if data =~ /(\d) days?, (\d\d):(\d\d):(\d\d)/
        days, hours, minutes, seconds = [$1, $2, $3, $4].map(&:to_i)
        @lease_expires_in = days * (60 * 60 * 24) + hours * (60 * 60) + minutes * 60 + seconds
      else
        raise "Could not parse date"
      end
    end

    def lease_expires_at
      Time.at(Time.now + lease_expires_in)
    end
  end
end
