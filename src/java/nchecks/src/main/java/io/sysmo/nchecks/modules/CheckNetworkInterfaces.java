/* Copyright (C) 2014, Sebastien Serre <sserre.bx@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

package io.sysmo.nchecks.modules;

import io.sysmo.nchecks.NHelperInterface2;
import io.sysmo.nchecks.NHelperReply;
import io.sysmo.nchecks.NHelperSimpleReply;
import io.sysmo.nchecks.NHelperTableReply;
import io.sysmo.nchecks.NHelperTableRow;
import io.sysmo.nchecks.NChecksLogger;

import io.sysmo.nchecks.NChecksInterface;
import io.sysmo.nchecks.Argument;
import io.sysmo.nchecks.Reply;
import io.sysmo.nchecks.Query;
import io.sysmo.nchecks.NChecksSNMP;

import org.snmp4j.Snmp;
import org.snmp4j.AbstractTarget;
import org.snmp4j.util.TableUtils;
import org.snmp4j.util.TableEvent;
import org.snmp4j.util.DefaultPDUFactory;
import org.snmp4j.smi.OID;
import org.snmp4j.smi.VariableBinding;
import org.snmp4j.PDU;

import java.util.Map;
import java.util.HashMap;
import java.util.Arrays;
import java.util.List;
import java.util.Iterator;
import java.io.CharArrayWriter;

import javax.json.Json;
import javax.json.JsonWriter;
import javax.json.JsonArray;
import javax.json.JsonArrayBuilder;
import javax.json.JsonBuilderFactory;
import javax.json.JsonObject;
import javax.json.JsonObjectBuilder;

import io.sysmo.nchecks.NChecksSNMP;
import org.snmp4j.Snmp;
import org.snmp4j.AbstractTarget;
import org.snmp4j.util.TableUtils;
import org.snmp4j.util.TableEvent;
import org.snmp4j.util.DefaultPDUFactory;
import org.snmp4j.smi.OID;
import org.snmp4j.smi.VariableBinding;
import org.snmp4j.PDU;


public class CheckNetworkInterfaces implements NChecksInterface, NHelperInterface2
{
    private static String IF_INDEX = "1.3.6.1.2.1.2.2.1.1";
    private static String IF_IN_OCTETS = "1.3.6.1.2.1.2.2.1.10";
    private static String IF_IN_UCASTPKTS = "1.3.6.1.2.1.2.2.1.11";
    private static String IF_IN_NUCASTPKTS = "1.3.6.1.2.1.2.2.1.12";
    private static String IF_IN_ERRORS = "1.3.6.1.2.1.2.2.1.14";
    private static String IF_OUT_OCTETS = "1.3.6.1.2.1.2.2.1.16";
    private static String IF_OUT_UCASTPKTS = "1.3.6.1.2.1.2.2.1.17";
    private static String IF_OUT_NUCASTPKTS = "1.3.6.1.2.1.2.2.1.18";
    private static String IF_OUT_ERRORS = "1.3.6.1.2.1.2.2.1.20";

    private static OID[] columns = new OID[]{
        new OID(IF_INDEX),
            new OID(IF_IN_OCTETS),
            new OID(IF_IN_UCASTPKTS),
            new OID(IF_IN_NUCASTPKTS),
            new OID(IF_IN_ERRORS),
            new OID(IF_OUT_OCTETS),
            new OID(IF_OUT_UCASTPKTS),
            new OID(IF_OUT_NUCASTPKTS),
            new OID(IF_OUT_ERRORS)
    };

    private String  ifSelection;

    public CheckNetworkInterfaces() {}

    public Reply execute(Query query)
    {
        Reply  reply = new Reply();
        String error = "undefined";

        try {
            ifSelection = query.get("if_selection").asString();
        } catch (Exception|Error e) {
            e.printStackTrace();
            reply.setStatus(Reply.STATUS_ERROR);
            reply.setReply("Missing or wrong argument: " + e);
            return reply;
        }

        try {
            AbstractTarget target = NChecksSNMP.getInstance().getTarget(query);
            System.out.println("snmptarget? " + target);

            Snmp session = NChecksSNMP.getInstance().getSnmpSession();
            System.out.println("snmpsession? " + session);


            // TODO try PDU.GETBULK then PDU.GETNEXT to degrade....
            // TODO keep degrade state in reply.setOpaqueData(v)
            TableUtils tablewalker =
                new TableUtils(
                        session,
                        new DefaultPDUFactory(PDU.GETNEXT));

            System.out.println("tableutils?" + tablewalker);

            // TODO set lower and upper bound indexes
            List<TableEvent> snmpReply = tablewalker.getTable(
                    target,
                    columns,
                    null,
                    null);

            // TODO degrade to PDU.GETNEXT if some vb(s) == null
            // TODO check if reply is valid. Whereis is the error status?

            String[]     indexesArray = ifSelection.split(",");
            List<String> indexesList  = Arrays.asList(indexesArray);

            Iterator<TableEvent> it = snmpReply.iterator();
            TableEvent evt;
            while (it.hasNext()) {
                evt = it.next();
                error = evt.getErrorMessage();
                VariableBinding[]   vbs = evt.getColumns();
                String ifIndex = vbs[0].getVariable().toString();
                if (indexesList.contains(ifIndex) == false) continue;
                reply.putPerformance(ifIndex,"IfInOctets",
                        vbs[1].getVariable().toLong());
                reply.putPerformance(ifIndex,"IfInUcastPkts",
                        vbs[2].getVariable().toLong());
                reply.putPerformance(ifIndex,"IfInNucastPkts",
                        vbs[3].getVariable().toLong());
                reply.putPerformance(ifIndex,"IfInErrors",
                        vbs[4].getVariable().toLong());

                reply.putPerformance(ifIndex,"IfOutOctets",
                        vbs[5].getVariable().toLong());
                reply.putPerformance(ifIndex,"IfOutUcastPkts",
                        vbs[6].getVariable().toLong());
                reply.putPerformance(ifIndex,"IfOutNucastPkts",
                        vbs[7].getVariable().toLong());
                reply.putPerformance(ifIndex,"IfOutErrors",
                        vbs[8].getVariable().toLong());
            }


            reply.setStatus(Reply.STATUS_OK);
            reply.setReply("IfPerTableTest success fetch for: " + ifSelection);
            return reply;
        } catch (Exception|Error e) {
            e.printStackTrace();
            reply.setStatus(Reply.STATUS_ERROR);
            reply.setReply("Error: " + error);
            return reply;
        }
    }

    /*
     * Helper interface
     */
    public NHelperReply callHelper(Query query, String id)
    {
        GetIfTableHelper helper = new GetIfTableHelper();
        NHelperReply reply = helper.call(query);
        return reply;
    }
}


class GetIfTableHelper
{

    private static final String IF_INDEX       = "1.3.6.1.2.1.2.2.1.1";
    private static final String IF_DESCR       = "1.3.6.1.2.1.2.2.1.2";
    private static final String IF_TYPE        = "1.3.6.1.2.1.2.2.1.3";
    private static final String IF_PHYSADDRESS = "1.3.6.1.2.1.2.2.1.6";

    private static final OID[] columns = new OID[]{
            new OID(IF_INDEX),
            new OID(IF_DESCR),
            new OID(IF_TYPE),
            new OID(IF_PHYSADDRESS)
    };

    private static final Map<String, String> iftype;
    static
    {
        iftype = new HashMap<String,String>();
        iftype.put("1", "other");
        iftype.put("2", "regular1822");
        iftype.put("3", "hdh1822");
        iftype.put("4", "ddn-x25");
        iftype.put("5", "rfc877-x25");
        iftype.put("6", "ethernet-csmacd");
        iftype.put("7", "iso88023-csmacd");
        iftype.put("8", "iso88024-tokenBus");
        iftype.put("9", "iso88025-tokenRing");
        iftype.put("10", "iso88026-man");
        iftype.put("11", "starLan");
        iftype.put("12", "proteon-10Mbit");
        iftype.put("13", "proteon-80Mbit");
        iftype.put("14", "hyperchannel");
        iftype.put("15", "fddi");
        iftype.put("16", "lapb");
        iftype.put("17", "sdlc");
        iftype.put("18", "ds1");
        iftype.put("19", "e1");
        iftype.put("20", "basicISDN");
        iftype.put("21", "primaryISDN");
        iftype.put("22", "propPointToPointSerial");
        iftype.put("23", "ppp");
        iftype.put("24", "softwareLoopback");
        iftype.put("25", "eon");
        iftype.put("26", "ethernet-3Mbit");
        iftype.put("27", "nsip");
        iftype.put("28", "slip");
        iftype.put("29", "ultra");
        iftype.put("30", "ds3");
        iftype.put("31", "sip");
        iftype.put("32", "frame-relay");
    }

    public GetIfTableHelper() {}

    public NHelperReply call(Query query)
    {
        try {
            AbstractTarget target = NChecksSNMP.getInstance().getTarget(query);

            Snmp session = NChecksSNMP.getInstance().getSnmpSession();
            TableUtils tablewalker =
                new TableUtils(
                        session,
                        new DefaultPDUFactory(PDU.GETNEXT));

            List<TableEvent> snmpReply = tablewalker.getTable(
                    target,
                    columns,
                    null,
                    null);

            Iterator<TableEvent> it = snmpReply.iterator();
            TableEvent evt;

            NHelperTableReply table = new NHelperTableReply();
            while (it.hasNext()) {
                evt = it.next();
                VariableBinding[]   vbs = evt.getColumns();
                NHelperTableRow     row = new NHelperTableRow();
                row.addItem("ifIndex", vbs[0].getVariable().toString());
                row.addItem("ifDescr", vbs[1].getVariable().toString());
                row.addItem("ifType", getType(vbs[2].getVariable().toString()));
                row.addItem("ifPhysAddress", vbs[3].getVariable().toString());
                table.addRow(row);
            }
            table.setId("SelectNetworkInterfaces");
            table.setStatus(NHelperReply.SUCCESS);
            return table;

        } catch (Exception|Error e) {
            NHelperSimpleReply simple = new NHelperSimpleReply();
            simple.setId("SelectNetworkInterfaces");
            simple.setStatus(NHelperReply.FAILURE);
            simple.setMessage(e.toString());
            return simple;
        }
    }

    private static String getType(String type)
    {
        String val = iftype.get(type);
        if (val == null) return "unknown(" + type + ")";
        return val;
    }
}
