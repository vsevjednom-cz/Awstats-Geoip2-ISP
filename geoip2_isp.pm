#!/usr/bin/perl
#-----------------------------------------------------------------------------
# GeoIp2-ISP AWStats plugin
#-----------------------------------------------------------------------------
# Perl Required Modules: Geo::IP or Geo::IP::PurePerl
#-----------------------------------------------------------------------------
# 1.0 - Lukas Janku

# <-----
# ENTER HERE THE USE COMMAND FOR ALL REQUIRED PERL MODULES
use vars qw/ $type /;
$type='geoip2';
if (!eval ('require "GeoIP2/Database/Reader.pm";')) {
	$error=$@;
    $ret=($error)?"Error:\n$error":"";
    $ret.="Error: Need Perl module GeoIP2::Database::Reader";
    return $ret;
}
# GeoIP2 Perl API doesn't have a ByName lookup so we need to do the resolution ourselves
if (!eval ('require "Socket.pm";')) {
	$error=$@;
    $ret=($error)?"Error:\n$error":"";
    $ret.="Error: Need Perl module Socket";
    return $ret;
}
# ----->
#use strict;
no strict "refs";



#-----------------------------------------------------------------------------
# PLUGIN VARIABLES
#-----------------------------------------------------------------------------
# <-----
# ENTER HERE THE MINIMUM AWSTATS VERSION REQUIRED BY YOUR PLUGIN
# AND THE NAME OF ALL FUNCTIONS THE PLUGIN MANAGE.
my $PluginNeedAWStatsVersion="6.5";
my $PluginHooksFunctions="AddHTMLMenuLink AddHTMLGraph ShowInfoHost SectionInitHashArray SectionProcessIp SectionProcessHostname SectionReadHistory SectionWriteHistory";
my $PluginName="geoip2_isp";
my $LoadedOverride=0;
my $OverrideFile="";
my %TmpDomainLookup = {}; 
# ----->

# <-----
# IF YOUR PLUGIN NEED GLOBAL VARIABLES, THEY MUST BE DECLARED HERE.
use vars qw/
$geoip2_isp
%_isp_p
%_isp_h
%_isp_k
%_isp_l
$MAXNBOFSECTIONGIR
/;
use Data::Validate::IP 0.25 qw( is_public_ip );
# ----->



#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: Init_pluginname
#-----------------------------------------------------------------------------
sub Init_geoip2_isp {
	my $InitParams=shift;
	my $checkversion=&Check_Plugin_Version($PluginNeedAWStatsVersion);
    $MAXNBOFSECTIONGIR=10;
    
	# <-----
	# ENTER HERE CODE TO DO INIT PLUGIN ACTIONS
	debug(" Plugin $PluginName: InitParams=$InitParams",1);
    my ($datafile,$override)=split(/\+/,$InitParams,2);
   	if (! $datafile) { $datafile="GeoIP2-ISP.mmdb"; }
   	else { $datafile =~ s/%20/ /g; }
	if ($override){ $override =~ s/%20/ /g; $OverrideFile=$override; }
	%TmpDomainLookup=();
	debug(" Plugin $PluginName: GeoIP2 initialized type=$type override=$override",1);
	$geoip2_isp = GeoIP2::Database::Reader->new(
        file    => $datafile,
        locales => [ 'en', 'de', ]);
	$LoadedOverride=0;
	# Fails on some GeoIP version
	# debug(" Plugin geoip2_isp: GeoIP initialized database_info=".$geoip2_isp->database_info());
	if ($geoip2_isp) { debug(" Plugin $PluginName: GeoIP2 plugin and gi object initialized",1); }
	else { return "Error: Failed to create gi object for datafile=".$datafile; }
	# ----->

	return ($checkversion?$checkversion:"$PluginHooksFunctions");
}


#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: AddHTMLMenuLink_pluginname
# UNIQUE: NO (Several plugins using this function can be loaded)
#-----------------------------------------------------------------------------
sub AddHTMLMenuLink_geoip2_isp {
    my $categ=$_[0];
    my $menu=$_[1];
    my $menulink=$_[2];
    my $menutext=$_[3];
	# <-----
	if ($Debug) { debug(" Plugin $PluginName: AddHTMLMenuLink"); }
    if ($categ eq 'who') {
        $menu->{"plugin_$PluginName"}=0.6;               # Pos
        $menulink->{"plugin_$PluginName"}=2;             # Type of link
        $menutext->{"plugin_$PluginName"}='ISP'; # Text
    }
	# ----->
	return 0;
}


#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: AddHTMLGraph_pluginname
# UNIQUE: NO (Several plugins using this function can be loaded)
#-----------------------------------------------------------------------------
sub AddHTMLGraph_geoip2_isp {
    my $categ=$_[0];
    my $menu=$_[1];
    my $menulink=$_[2];
    my $menutext=$_[3];
	# <-----
    my $ShowCities='H';
	$MinHit{'Cities'}=1;
	my $total_p; my $total_h; my $total_k;
	my $rest_p; my $rest_h; my $rest_k;

	if ($Debug) { debug(" Plugin $PluginName: AddHTMLGraph $categ $menu $menulink $menutext"); }
	my $title="GeoIP2 ISP";
	&tab_head($title,19,0,'isp');
	print "<tr bgcolor=\"#$color_TableBGRowTitle\">";
	print "<th>ISP: ".((scalar keys %_isp_h)-($_isp_h{'unknown'}?1:0))."</th>";

	if ($ShowCities =~ /P/i) { print "<th bgcolor=\"#$color_p\" width=\"80\">$Message[56]</th>"; }
	if ($ShowCities =~ /P/i) { print "<th bgcolor=\"#$color_p\" width=\"80\">$Message[15]</th>"; }
	if ($ShowCities =~ /H/i) { print "<th bgcolor=\"#$color_h\" width=\"80\">$Message[57]</th>"; }
	if ($ShowCities =~ /H/i) { print "<th bgcolor=\"#$color_h\" width=\"80\">$Message[15]</th>"; }
	if ($ShowCities =~ /B/i) { print "<th bgcolor=\"#$color_k\" width=\"80\">$Message[75]</th>"; }
	if ($ShowCities =~ /L/i) { print "<th width=\"120\">$Message[9]</th>"; }
	print "</tr>\n";
	$total_p=$total_h=$total_k=0;
	my $count=0;
	&BuildKeyList($MaxRowsInHTMLOutput,$MinHit{'Cities'},\%_isp_h,\%_isp_h);
    	foreach my $key (@keylist) {
            if ($key eq 'unknown') { next; }
   		    my ($isp)=split('_', $key, 2);
            $isp=~s/%20/ /g;
   			my $p_p; my $p_h;
			if ($TotalPages) { $p_p=int(($_isp_p{$key}||0)/$TotalPages*1000)/10; }
   			if ($TotalHits)  { $p_h=int($_isp_h{$key}/$TotalHits*1000)/10; }
   		    print "<tr>";
   		    print "<td class=\"aws\">".ucfirst(EncodeToPageCode($isp))."</td>";
    		if ($ShowCities =~ /P/i) { print "<td>".($_isp_p{$key}?Format_Number($_isp_p{$key}):"&nbsp;")."</td>"; }
    		if ($ShowCities =~ /P/i) { print "<td>".($_isp_p{$key}?"$p_p %":'&nbsp;')."</td>"; }
    		if ($ShowCities =~ /H/i) { print "<td>".($_isp_h{$key}?Format_Number($_isp_h{$key}):"&nbsp;")."</td>"; }
    		if ($ShowCities =~ /H/i) { print "<td>".($_isp_h{$key}?"$p_h %":'&nbsp;')."</td>"; }
    		if ($ShowCities =~ /B/i) { print "<td>".Format_Bytes($_isp_k{$key})."</td>"; }
    		if ($ShowCities =~ /L/i) { print "<td>".($_isp_p{$key}?Format_Date($_isp_l{$key},1):'-')."</td>"; }
    		print "</tr>\n";
    		$total_p += $_isp_p{$key}||0;
    		$total_h += $_isp_h{$key};
    		$total_k += $_isp_k{$key}||0;
    		$count++;
    	}
	if ($Debug) { debug("Total real / shown : $TotalPages / $total_p - $TotalHits / $total_h - $TotalBytes / $total_h",2); }
	$rest_p=0;
	$rest_h=$TotalHits-$total_h;
	$rest_k=0;
	if ($rest_p > 0 || $rest_h > 0 || $rest_k > 0) {	# All other cities

		my $p_p; my $p_h;
		if ($TotalPages) { $p_p=int($rest_p/$TotalPages*1000)/10; }
		if ($TotalHits)  { $p_h=int($rest_h/$TotalHits*1000)/10; }
		print "<tr>";
		print "<td class=\"aws\"><span style=\"color: #$color_other\">$Message[2]/$Message[0]</span></td>";
		if ($ShowCities =~ /P/i) { print "<td>".($rest_p?$rest_p:"&nbsp;")."</td>"; }
   		if ($ShowCities =~ /P/i) { print "<td>".($rest_p?"$p_p %":'&nbsp;')."</td>"; }
		if ($ShowCities =~ /H/i) { print "<td>".($rest_h?$rest_h:"&nbsp;")."</td>"; }
   		if ($ShowCities =~ /H/i) { print "<td>".($rest_h?"$p_h %":'&nbsp;')."</td>"; }
		if ($ShowCities =~ /B/i) { print "<td>".Format_Bytes($rest_k)."</td>"; }
		if ($ShowCities =~ /L/i) { print "<td>&nbsp;</td>"; }
		print "</tr>\n";
	}
	&tab_end();

	# ----->
	return 0;
}

#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: ShowInfoHost_pluginname
# UNIQUE: NO (Several plugins using this function can be loaded)
# Function called to add additionnal columns to the Hosts report.
# This function is called when building rows of the report (One call for each
# row). So it allows you to add a column in report, for example with code :
#   print "<TD>This is a new cell for $param</TD>";
# Parameters: Host name or ip
#-----------------------------------------------------------------------------
sub ShowInfoHost_geoip2_isp {
    my $param="$_[0]";
	# <-----
	if ($param eq '__title__')
	{
    	my $NewLinkParams=${QueryString};
    	$NewLinkParams =~ s/(^|&|&amp;)update(=\w*|$)//i;
    	$NewLinkParams =~ s/(^|&|&amp;)output(=\w*|$)//i;
    	$NewLinkParams =~ s/(^|&|&amp;)staticlinks(=\w*|$)//i;
    	$NewLinkParams =~ s/(^|&|&amp;)framename=[^&]*//i;
    	my $NewLinkTarget='';
    	if ($DetailedReportsOnNewWindows) { $NewLinkTarget=" target=\"awstatsbis\""; }
    	if (($FrameName eq 'mainleft' || $FrameName eq 'mainright') && $DetailedReportsOnNewWindows < 2) {
    		$NewLinkParams.="&framename=mainright";
    		$NewLinkTarget=" target=\"mainright\"";
    	}
    	$NewLinkParams =~ s/(&amp;|&)+/&amp;/i;
    	$NewLinkParams =~ s/^&amp;//; $NewLinkParams =~ s/&amp;$//;
    	if ($NewLinkParams) { $NewLinkParams="${NewLinkParams}&"; }

#		print "<th width=\"80\">";
#        print "<a href=\"".($ENV{'GATEWAY_INTERFACE'} || !$StaticLinks?XMLEncode("$AWScript?${NewLinkParams}output=plugin_geoip2_isp&amp;suboutput=country"):"$PROG$StaticLinks.plugin_geoip2_isp.country.$StaticExt")."\"$NewLinkTarget>GeoIP2<br/>Country</a>";
#        print "</th>";
		print "<th width=\"80\">";
        print "<a href=\"".($ENV{'GATEWAY_INTERFACE'} || !$StaticLinks?XMLEncode("$AWScript?${NewLinkParams}output=plugin_$PluginName"):"$StaticLinks.plugin_$PluginName.$StaticExt")."\"$NewLinkTarget>GeoIP2<br/>ISP</a>";
        print "</th>";
	}
	elsif ($param)
	{
		my ($country, $city, $subdivision) = Lookup_geoip2_isp($param);
#		print "<td>";
#		if ($country) { print $DomainsHashIDLib{$country}?$DomainsHashIDLib{$country}:"<span style=\"color: #$color_other\">$Message[0]</span>"; }
#		else { print "<span style=\"color: #$color_other\">$Message[0]</span>"; }
#		print "</td>";
		print "<td>";
		if ($city) { print EncodeToPageCode($city); }
		else { print "<span style=\"color: #$color_other\">$Message[0]</span>"; }
		print "</td>";
	}
	else
	{ print "<td>&nbsp;</td>"; }
	return 1;
	# ----->
}


#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: SectionInitHashArray_pluginname
# UNIQUE: NO (Several plugins using this function can be loaded)
#-----------------------------------------------------------------------------
sub SectionInitHashArray_geoip2_isp {
#    my $param="$_[0]";
	# <-----
	if ($Debug) { debug(" Plugin $PluginName: Init_HashArray"); }
	%_isp_p = %_isp_h = %_isp_k = %_isp_l =();
	# ----->
	return 0;
}


#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: SectionProcessIP_pluginname
# UNIQUE: NO (Several plugins using this function can be loaded)
#-----------------------------------------------------------------------------
sub SectionProcessIp_geoip2_isp {
	my $param = shift;
	my $rec = 'unknown';
	my ($country, $city, $subdivision) = Lookup_geoip2_isp($param);
	if ($country && $city) {
			$rec = $country . '_' . $city;
			$rec .= '_' . $subdivision if ($subdivision);
			$rec =~ s/ /%20/g;
			# escape non-latin1 chars
			$rec =~ s/([^\x00-\x7F])/sprintf "&#x%X;", ord($1)/ge;
			$rec = lc($rec);
	}
	$_isp_h{$rec}++;
	return;
}


#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: SectionProcessHostname_pluginname
# UNIQUE: NO (Several plugins using this function can be loaded)
#-----------------------------------------------------------------------------
sub SectionProcessHostname_geoip2_isp {
	return SectionProcessIp_geoip2_isp(@_);
}


#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: SectionReadHistory_pluginname
# UNIQUE: NO (Several plugins using this function can be loaded)
#-----------------------------------------------------------------------------
sub SectionReadHistory_geoip2_isp {
    my $issectiontoload=shift;
    my $xmlold=shift;
    my $xmleb=shift;
	my $countlines=shift;
	# <-----
	if ($Debug) { debug(" Plugin $PluginName: Begin of PLUGIN_geoip2_isp section"); }
	my @field=();
	my $count=0;my $countloaded=0;
	do {
		if ($field[0]) {
			$count++;
			if ($issectiontoload) {
				$countloaded++;
				if ($field[2]) { $_isp_h{$field[0]}+=$field[2]; }
			}
		}
		$_=<HISTORY>;
		chomp $_; s/\r//;
		@field=split(/\s+/,($xmlold?XMLDecodeFromHisto($_):$_));
		$countlines++;
	}
	until ($field[0] eq "END_PLUGIN_$PluginName" || $field[0] eq "${xmleb}END_PLUGIN_$PluginName" || ! $_);
	if ($field[0] ne "END_PLUGIN_$PluginName" && $field[0] ne "${xmleb}END_PLUGIN_$PluginName") { error("History file is corrupted (End of section PLUGIN not found).\nRestore a recent backup of this file (data for this month will be restored to backup date), remove it (data for month will be lost), or remove the corrupted section in file (data for at least this section will be lost).","","",1); }
	if ($Debug) { debug(" Plugin $PluginName: End of PLUGIN_$PluginName section ($count entries, $countloaded loaded)"); }
	# ----->
	return 0;
}

#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: SectionWriteHistory_pluginname
# UNIQUE: NO (Several plugins using this function can be loaded)
#-----------------------------------------------------------------------------
sub SectionWriteHistory_geoip2_isp {
    my ($xml,$xmlbb,$xmlbs,$xmlbe,$xmlrb,$xmlrs,$xmlre,$xmleb,$xmlee)=(shift,shift,shift,shift,shift,shift,shift,shift,shift);
    if ($Debug) { debug(" Plugin $PluginName: SectionWriteHistory_$PluginName start - ".(scalar keys %_isp_h)); }
	# <-----
	print HISTORYTMP "\n";
	if ($xml) { print HISTORYTMP "<section id='plugin_$PluginName'><sortfor>$MAXNBOFSECTIONGIR</sortfor><comment>\n"; }
	print HISTORYTMP "# Plugin key - Pages - Hits - Bandwidth - Last access\n";
	#print HISTORYTMP "# The $MaxNbOfExtra[$extranum] first number of hits are first\n";
	$ValueInFile{"plugin_$PluginName"}=tell HISTORYTMP;
	print HISTORYTMP "${xmlbb}BEGIN_PLUGIN_$PluginName${xmlbs}".(scalar keys %_isp_h)."${xmlbe}\n";
	&BuildKeyList($MAXNBOFSECTIONGIR,1,\%_isp_h,\%_isp_h);
	my %keysinkeylist=();
	foreach (@keylist) {
		$keysinkeylist{$_}=1;
		#my $page=$_isp_p{$_}||0;
		#my $bytes=$_isp_k{$_}||0;
		#my $lastaccess=$_isp_l{$_}||'';
		print HISTORYTMP "${xmlrb}".XMLEncodeForHisto($_)."${xmlrs}0${xmlrs}", $_isp_h{$_}, "${xmlrs}0${xmlrs}0${xmlre}\n"; next;
	}
	foreach (keys %_isp_h) {
		if ($keysinkeylist{$_}) { next; }
		#my $page=$_isp_p{$_}||0;
		#my $bytes=$_isp_k{$_}||0;
		#my $lastaccess=$_isp_l{$_}||'';
		print HISTORYTMP "${xmlrb}".XMLEncodeForHisto($_)."${xmlrs}0${xmlrs}", $_isp_h{$_}, "${xmlrs}0${xmlrs}0${xmlre}\n"; next;
	}
	print HISTORYTMP "${xmleb}END_PLUGIN_$PluginName${xmlee}\n";
	# ----->
	return 0;
}

#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: LoadOverrideFile
# Attempts to load a comma delimited file that will override the GeoIP database
# Useful for Intranet records
# CSV format: IP,2-char Country code, region, city, postal code, latitude, 
#				longitude, US metro code, US area code
#-----------------------------------------------------------------------------
sub LoadOverrideFile_geoip2_isp{
	my $filetoload="";
	if ($OverrideFile){
		if (!open(GEOIPFILE, $OverrideFile)){
			debug("Plugin $PluginName: Unable to open override file: $OverrideFile");
			$LoadedOverride = 1;
			return;
		}
	}else{
		my $conf = (exists(&Get_Config_Name) ? Get_Config_Name() : $SiteConfig);
		if ($conf && open(GEOIPFILE,"$DirData/$PluginName.$conf.txt"))	{ $filetoload="$DirData/$PluginName.$conf.txt"; }
		elsif (open(GEOIPFILE,"$DirData/$PluginName.txt"))	{ $filetoload="$DirData/$PluginName.txt"; }
		else { debug("No override file \"$DirData/$PluginName.txt\": $!"); }
	}
	if ($filetoload)
	{
		# This is the fastest way to load with regexp that I know
		while (<GEOIPFILE>){
			chomp $_;
			s/\r//;
			my @record = split(",", $_);
			# replace quotes if they were used in the file
			foreach (@record){ $_ =~ s/"//g; }
			# now we need to copy our file values in the order to mimic the lookup values
			my @res = ();
			$res[0] = $record[1];
			$res[3] = $record[2];
			$res[4] = $record[3];
			$res[5] = $record[4];
			$res[6] = $record[5];
			$res[7] = $record[6];
			$res[8] = $record[7];
			$res[9] = $record[8];
			# store in hash
			$TmpDomainLookup{$record[0]} = [@res];
		}
		close GEOIPFILE;
        debug(" Plugin $PluginName: Overload file loaded: ".(scalar keys %TmpDomainLookup)." entries found.");
	}
	$LoadedOverride = 1;
	return;
}

#-----------------------------------------------------------------------------
# PLUGIN FUNCTION: Lookup
# Looks up the input parameter (either ip address or dns name) and returns its
# associated country code, city and subdivision name; or undefined if not available.
# GEOIP entry
#-----------------------------------------------------------------------------
sub Lookup_geoip2_isp {
	$param = shift;
	if (!$LoadedOverride) { &LoadOverrideFile_geoip2_isp(); }
	if ($Debug) { debug("  Plugin $PluginName: Lookup_geoip2_isp for $param",5); }
	if ($geoip2_isp && !exists($TmpDomainLookup{$param})) {
		$TmpDomainLookup{$param} = [ undef ]; # negative entry to avoid repeated lookups
		# Resolve the parameter (either a name or an ip address) to a list of network addresses
		my ($err, @result) = Socket::getaddrinfo($param, undef, { protocol => Socket::IPPROTO_TCP, socktype => Socket::SOCK_STREAM });
		for (@result) {
			# Convert the network address to human-readable form
			my ($err, $address, $servicename) = Socket::getnameinfo($_->{addr}, Socket::NI_NUMERICHOST, Socket::NIx_NOSERV);
			next if ($err || !is_public_ip($address));

			if ($Debug && $param ne $address) { debug("  Plugin $PluginName: Lookup_geoip2_isp $param resolved to $address",5); }
			eval {
				my $record = $geoip2_isp->isp(ip => $address);
#				my $country = $record->country()->iso_code();
				# FIXME
				# We strongly discourage you from using a value from any names accessor as a key in a database or hash.
				# See: https://github.com/maxmind/GeoIP2-perl#values-to-use-for-database-or-hash-keys
				my $isp = $record->isp();
#				my $subdivision = $record->most_specific_subdivision()->name();
				$TmpDomainLookup{$param} = [ $isp, $isp ];
				last;
			}
		}
	}
	my @res = @{ $TmpDomainLookup{$param} };
	if ($Debug) { debug("  Plugin $PluginName: Lookup_geoip2_isp for $param: [@res]",5); }
	return @res;
}

1;	# Do not remove this line
