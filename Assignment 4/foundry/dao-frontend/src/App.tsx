import { type JSX, useCallback, useEffect, useMemo, useState } from "react";
import {
  Alert,
  Button,
  Card,
  Col,
  Descriptions,
  Input,
  Layout,
  Radio,
  Row,
  Select,
  Space,
  Table,
  Tag,
  Typography,
  message,
} from "antd";
import { BrowserProvider, Contract, Interface, formatUnits, getAddress, isHexString, keccak256, toUtf8Bytes } from "ethers";

import { governorAbi, tokenAbi, boxAbi } from "./contractAbi";

const { Header, Content } = Layout;

const boxIface = new Interface(["function store(uint256 newValue)"]);

const PROPOSAL_LABELS = ["Pending", "Active", "Canceled", "Defeated", "Succeeded", "Queued", "Expired", "Executed"] as const;

type WindowWithEth = Window & { ethereum?: { request: (args: { method: string; params?: unknown[] }) => Promise<unknown> } };

function describeSupport(s: number): string {
  if (s === 0) return "Against";
  if (s === 1) return "For";
  if (s === 2) return "Abstain";
  return `Unknown (${s})`;
}

export interface ProposalRow {
  proposalId: bigint;
  proposer: string;
  targets: string[];
  values: bigint[];
  calldatas: string[];
  voteStart: bigint;
  voteEnd: bigint;
  description: string;
  descriptionHash: string;
}

export function App(): JSX.Element {
  const [account, setAccount] = useState<string | null>(null);
  const [chainId, setChainId] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [tokenSymbol, setTokenSymbol] = useState("DGVT");
  const [balance, setBalance] = useState<string>("—");
  const [votingPower, setVotingPower] = useState<string>("—");
  const [delegatee, setDelegatee] = useState<string>("—");
  const [delegateInput, setDelegateInput] = useState("");
  const [boxValue, setBoxValue] = useState<string>("—");
  const [proposals, setProposals] = useState<ProposalRow[]>([]);
  const [proposalMeta, setProposalMeta] = useState<
    Record<
      string,
      { state: number; forVotes: bigint; againstVotes: bigint; abstainVotes: bigint; quorumNeeded: bigint | undefined }
    >
  >({});
  const [voteChoice, setVoteChoice] = useState<Record<string, number>>({});
  const [clockMode, setClockMode] = useState<string>("");

  const [proposeDescription, setProposeDescription] = useState("");
  const [proposeTarget, setProposeTarget] = useState("");
  const [proposeEthValue, setProposeEthValue] = useState("0");
  const [proposePayload, setProposePayload] = useState<"boxStore" | "custom">("boxStore");
  const [boxStoreUint, setBoxStoreUint] = useState("42");
  const [customCalldata, setCustomCalldata] = useState("");

  const tokenAddr = import.meta.env.VITE_TOKEN_ADDRESS;
  const govAddr = import.meta.env.VITE_GOVERNOR_ADDRESS;
  const boxAddr = import.meta.env.VITE_BOX_ADDRESS;
  const fromBlock = Number(import.meta.env.VITE_PROPOSALS_FROM_BLOCK ?? "0");

  const configOk = useMemo(
    () =>
      tokenAddr &&
      govAddr &&
      tokenAddr !== "0x0000000000000000000000000000000000000000" &&
      govAddr !== "0x0000000000000000000000000000000000000000",
    [tokenAddr, govAddr],
  );

  const bootstrap = useCallback(async () => {
    const eth = (window as WindowWithEth).ethereum;
    if (!eth) return;
    const hex = (await eth.request({ method: "eth_chainId" })) as string;
    setChainId(BigInt(hex).toString());
  }, []);

  useEffect(() => {
    bootstrap();
  }, [bootstrap]);

  useEffect(() => {
    if (boxAddr && boxAddr !== "0x0000000000000000000000000000000000000000") {
      setProposeTarget((t) => (t === "" ? boxAddr : t));
    }
  }, [boxAddr]);

  const readProvider = useCallback(() => {
    const eth = (window as WindowWithEth).ethereum;
    if (!eth) throw new Error("MetaMask not detected");
    return new BrowserProvider(eth);
  }, []);

  const refreshAccount = useCallback(async () => {
    if (!account || !tokenAddr) return;
    const provider = readProvider();
    const token = new Contract(tokenAddr, tokenAbi, provider);
    const gov = new Contract(govAddr, governorAbi, provider);
    const rawBal: bigint = await token.balanceOf(account);
    const dec: number = Number(await token.decimals());
    const votes: bigint = await token.getVotes(account);
    const del: string = await token.delegates(account);
    setBalance(formatUnits(rawBal, dec));
    setVotingPower(formatUnits(votes, dec));
    setDelegatee(del);
    try {
      const mode: string = await gov.CLOCK_MODE();
      setClockMode(mode);
    } catch {
      setClockMode("(unknown)");
    }
  }, [account, govAddr, readProvider, tokenAddr]);

  useEffect(() => {
    void refreshAccount();
  }, [refreshAccount]);

  const refreshBox = useCallback(async () => {
    if (!boxAddr || boxAddr === "0x0000000000000000000000000000000000000000") {
      setBoxValue("—");
      return;
    }
    const provider = readProvider();
    const box = new Contract(boxAddr, boxAbi, provider);
    const v = await box.retrieve();
    setBoxValue(v.toString());
  }, [boxAddr, readProvider]);

  useEffect(() => {
    void refreshBox();
  }, [refreshBox]);

  const hydrateProposals = useCallback(
    async (rows: ProposalRow[]) => {
      const provider = readProvider();
      const gov = new Contract(govAddr, governorAbi, provider);
      const clockNow = BigInt(await gov.clock());
      const next: Record<
        string,
        { state: number; forVotes: bigint; againstVotes: bigint; abstainVotes: bigint; quorumNeeded: bigint | undefined }
      > = {};
      await Promise.all(
        rows.map(async (row) => {
          const pid = row.proposalId;
          const st: number = Number(await gov.state(pid));
          const [againstVotes, forVotes, abstainVotes]: [bigint, bigint, bigint] = await gov.proposalVotes(pid);
          const snapshot: bigint = await gov.proposalSnapshot(pid);
          let quorumNeeded: bigint | undefined;
          if (snapshot < clockNow) {
            quorumNeeded = await gov.quorum(snapshot);
          }
          next[pid.toString()] = {
            state: st,
            forVotes,
            againstVotes,
            abstainVotes,
            quorumNeeded,
          };
        }),
      );
      setProposalMeta(next);
    },
    [govAddr, readProvider],
  );

  const loadProposals = useCallback(async () => {
    if (!configOk || !govAddr) return;
    setBusy(true);
    try {
      const provider = readProvider();
      const gov = new Contract(govAddr, governorAbi, provider);
      const latest = await provider.getBlockNumber();
      const iface = new Interface(governorAbi);
      const logs = await gov.queryFilter(gov.filters.ProposalCreated(), fromBlock, latest);
      const rows: ProposalRow[] = logs
        .map((log): ProposalRow | null => {
          const parsed = iface.parseLog(log);
          if (!parsed || parsed.name !== "ProposalCreated") return null;
          const [proposalId, proposer, targets, values, _sigs, calldatas, voteStart, voteEnd, description] = parsed.args as unknown as [
            bigint,
            string,
            string[],
            bigint[],
            string[],
            string[],
            bigint,
            bigint,
            string,
          ];
          return {
            proposalId,
            proposer,
            targets: [...targets],
            values: [...values],
            calldatas: [...calldatas],
            voteStart,
            voteEnd,
            description,
            descriptionHash: keccak256(toUtf8Bytes(description)),
          };
        })
        .filter(Boolean) as ProposalRow[];
      rows.sort((a, b) => (a.proposalId < b.proposalId ? 1 : -1));
      setProposals(rows);
      await hydrateProposals(rows);
      try {
        setTokenSymbol(await new Contract(tokenAddr, tokenAbi, provider).symbol());
      } catch {
        setTokenSymbol("DGVT");
      }
      message.success(`Loaded ${rows.length} proposals`);
    } catch (e) {
      console.error(e);
      message.error("Failed loading proposals — check RPC and contract addresses");
    } finally {
      setBusy(false);
    }
  }, [configOk, fromBlock, govAddr, hydrateProposals, readProvider, tokenAddr]);

  async function connect(): Promise<void> {
    try {
      setBusy(true);
      const eth = (window as WindowWithEth).ethereum;
      if (!eth) throw new Error("Install MetaMask");
      const accounts = (await eth.request({
        method: "eth_requestAccounts",
      })) as string[];
      setAccount(accounts[0]);
      bootstrap();
      message.success("Wallet connected");
    } catch (e) {
      message.error(String(e));
    } finally {
      setBusy(false);
    }
  }

  async function delegate(): Promise<void> {
    if (!account || !delegateInput) return;
    try {
      setBusy(true);
      const provider = readProvider();
      const signer = await provider.getSigner();
      const token = new Contract(tokenAddr, tokenAbi, signer);
      const tx = await token.delegate(delegateInput);
      await tx.wait();
      message.success("Delegated");
      await refreshAccount();
    } catch (e) {
      message.error(String(e));
    } finally {
      setBusy(false);
    }
  }

  async function castVote(pid: bigint): Promise<void> {
    const support = voteChoice[pid.toString()] ?? 1;
    try {
      setBusy(true);
      const provider = readProvider();
      const signer = await provider.getSigner();
      const gov = new Contract(govAddr, governorAbi, signer);
      const tx = await gov.castVote(pid, support);
      await tx.wait();
      message.success(`Voted (${describeSupport(support)})`);
      await refreshAccount();
      await loadProposals();
    } catch (e) {
      message.error(String(e));
    } finally {
      setBusy(false);
    }
  }

  async function queueProposal(row: ProposalRow): Promise<void> {
    try {
      setBusy(true);
      const provider = readProvider();
      const signer = await provider.getSigner();
      const gov = new Contract(govAddr, governorAbi, signer);
      const tx = await gov.queue(row.targets, row.values, row.calldatas, row.descriptionHash);
      await tx.wait();
      message.success("Queued for timelock");
      await loadProposals();
    } catch (e) {
      message.error(String(e));
    } finally {
      setBusy(false);
    }
  }

  async function submitProposal(): Promise<void> {
    if (!account) {
      message.warning("Connect a wallet first");
      return;
    }
    if (!proposeDescription.trim()) {
      message.warning("Add a description (used in the proposal id hash)");
      return;
    }
    if (!proposeTarget.trim()) {
      message.warning("Set target contract address");
      return;
    }
    let target: string;
    try {
      target = getAddress(proposeTarget.trim());
    } catch {
      message.error("Invalid target address");
      return;
    }
    let calldata: string;
    if (proposePayload === "boxStore") {
      let n: bigint;
      try {
        n = BigInt(boxStoreUint.trim() || "0");
      } catch {
        message.error("Box value must be an integer (uint256)");
        return;
      }
      try {
        calldata = boxIface.encodeFunctionData("store", [n]);
      } catch (e) {
        message.error(`encode store failed: ${String(e)}`);
        return;
      }
    } else {
      const hx = customCalldata.trim();
      if (!hx.startsWith("0x") || !isHexString(hx)) {
        message.error("Custom calldata must be hex starting with 0x");
        return;
      }
      calldata = hx;
    }
    let valueWei: bigint;
    try {
      valueWei = BigInt(proposeEthValue.trim() || "0");
    } catch {
      message.error("ETH value must be a non-negative integer (wei)");
      return;
    }
    try {
      setBusy(true);
      const provider = readProvider();
      const signer = await provider.getSigner();
      const gov = new Contract(govAddr, governorAbi, signer);
      const tx = await gov.propose([target], [valueWei], [calldata], proposeDescription.trim());
      await tx.wait();
      message.success("Proposal created");
      setProposeDescription("");
      await loadProposals();
      await refreshAccount();
    } catch (e) {
      message.error(String(e));
    } finally {
      setBusy(false);
    }
  }

  async function executeProposal(row: ProposalRow): Promise<void> {
    try {
      setBusy(true);
      const provider = readProvider();
      const signer = await provider.getSigner();
      const gov = new Contract(govAddr, governorAbi, signer);
      const tx = await gov.execute(row.targets, row.values, row.calldatas, row.descriptionHash);
      await tx.wait();
      message.success("Proposal executed via timelock");
      await loadProposals();
      await refreshBox();
    } catch (e) {
      message.error(String(e));
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    void loadProposals();
  }, [configOk]);

  const columns = [
    { title: "ID", key: "id", render: (_: unknown, r: ProposalRow) => String(r.proposalId) },
    {
      title: "State",
      key: "st",
      render: (_: unknown, r: ProposalRow) => {
        const st = proposalMeta[r.proposalId.toString()]?.state ?? "?";
        const label = typeof st === "number" ? PROPOSAL_LABELS[st] ?? `${st}` : `${st}`;
        const color =
          label === "Active"
            ? "processing"
            : label === "Succeeded" || label === "Queued"
              ? "cyan"
              : label === "Executed"
                ? "success"
                : label === "Defeated" || label === "Canceled"
                  ? "error"
                  : "default";
        return <Tag color={color}>{label}</Tag>;
      },
    },
    { title: "Description", key: "desc", render: (_: unknown, r: ProposalRow) => <span style={{ maxWidth: 360, display: "inline-block", wordBreak: "break-word" }}>{r.description}</span> },
    {
      title: "Tally (" + tokenSymbol + ", raw units)",
      key: "votes",
      render: (_: unknown, r: ProposalRow) => {
        const m = proposalMeta[r.proposalId.toString()];
        if (!m) return "—";
        const cast = m.forVotes + m.againstVotes + m.abstainVotes;
        return (
          <Space direction="vertical" size={0}>
            <span>
              For: {m.forVotes.toString()} · Against: {m.againstVotes.toString()} · Abstain: {m.abstainVotes.toString()}
            </span>
            <span style={{ opacity: 0.75 }}>
              Turnout raw: {cast.toString()}
              {" · Quorum required: "}
              {m.quorumNeeded !== undefined ? m.quorumNeeded.toString() : "— (after voting begins)"}
            </span>
          </Space>
        );
      },
    },
    {
      title: "Actions",
      key: "acts",
      width: 360,
      render: (_: unknown, r: ProposalRow) => {
        const meta = proposalMeta[r.proposalId.toString()];
        const stateName = typeof meta?.state === "number" ? PROPOSAL_LABELS[meta.state] : "";
        return (
          <Space direction="vertical" style={{ width: "100%" }}>
            {stateName === "Active" && (
              <>
                <Radio.Group
                  value={voteChoice[r.proposalId.toString()] ?? 1}
                  onChange={(ev) =>
                    setVoteChoice((prev) => ({
                      ...prev,
                      [r.proposalId.toString()]: Number(ev.target.value),
                    }))
                  }
                >
                  <Radio.Button value={1}>For</Radio.Button>
                  <Radio.Button value={0}>Against</Radio.Button>
                  <Radio.Button value={2}>Abstain</Radio.Button>
                </Radio.Group>
                <Button type="primary" size="small" onClick={() => castVote(r.proposalId)} disabled={busy || !account}>
                  Cast vote
                </Button>
              </>
            )}
            {stateName === "Pending" && <Tag>Waiting for voting delay</Tag>}
            {stateName === "Succeeded" && (
              <Button size="small" onClick={() => queueProposal(r)}>
                Queue (timelock)
              </Button>
            )}
            {stateName === "Queued" && (
              <Button size="small" type="primary" onClick={() => executeProposal(r)}>
                Execute after delay
              </Button>
            )}
          </Space>
        );
      },
    },
  ];

  return (
    <Layout>
      <Header style={{ display: "flex", alignItems: "center", justifyContent: "space-between", paddingInline: 24 }}>
        <Typography.Title level={3} style={{ margin: 0, color: "#fff" }}>
          DAO Governance Console
        </Typography.Title>
        <Space>
          {chainId && <Typography.Text style={{ color: "#bfbfbf" }}>chainId {chainId}</Typography.Text>}
          <Button type="primary" onClick={() => loadProposals()} loading={busy}>
            Refresh proposals
          </Button>
          <Button onClick={() => connect()} loading={busy}>
            {account ? `${account.slice(0, 6)}…${account.slice(-4)}` : "Connect MetaMask"}
          </Button>
        </Space>
      </Header>
      <Content style={{ padding: "24px 48px", maxWidth: 1200, marginInline: "auto", width: "100%" }}>
        {!configOk && (
          <Alert
            style={{ marginBottom: 24 }}
            type="warning"
            showIcon
            message="Configure contract addresses"
            description="Copy .env.example to .env.local and set VITE_TOKEN_ADDRESS and VITE_GOVERNOR_ADDRESS (and optional BOX)."
          />
        )}
        <Row gutter={[24, 24]}>
          <Col xs={24} lg={12}>
            <Card title="Governance token" loading={busy && !account}>
              <Descriptions column={1} size="small" bordered layout="horizontal">
                <Descriptions.Item label="Clock mode">{clockMode}</Descriptions.Item>
                <Descriptions.Item label="Balance">{balance}</Descriptions.Item>
                <Descriptions.Item label="Voting power">{votingPower}</Descriptions.Item>
                <Descriptions.Item label="Delegated to">{delegatee}</Descriptions.Item>
              </Descriptions>
              <Typography.Paragraph style={{ marginTop: 16 }} type="secondary">
                Activate voting weight by delegating to yourself or a trusted delegatee.
              </Typography.Paragraph>
              <Space.Compact style={{ width: "100%" }}>
                <Input placeholder="Hex delegate address" value={delegateInput} onChange={(e) => setDelegateInput(e.target.value.trim())} />
                <Button type="primary" onClick={() => delegate()} disabled={!account || busy}>
                  Delegate
                </Button>
              </Space.Compact>
            </Card>
          </Col>
          <Col xs={24} lg={12}>
            <Card title={`Box.retrieve() (${boxAddr?.slice(0, 10) ?? "unset"}…)`}>
              <Typography.Title level={2} style={{ marginTop: 0 }}>
                {boxValue}
              </Typography.Title>
              <Typography.Paragraph type="secondary">Updated whenever governance executes a successful proposal targeting Box.</Typography.Paragraph>
              <Button onClick={() => refreshBox()} size="small">
                Refresh Box
              </Button>
            </Card>
          </Col>
        </Row>

        <Card title="Create proposal" style={{ marginTop: 24 }}>
          <Typography.Paragraph type="secondary">
            You need enough delegated voting power to meet the governor&apos;s <code>proposalThreshold</code> (checked at <code>clock() - 1</code>).
            Use a unique description if you repeat the same on-chain action.
          </Typography.Paragraph>
          <Space direction="vertical" size="middle" style={{ width: "100%" }}>
            <Input
              placeholder="Description (e.g. Set box to 99 #2)"
              value={proposeDescription}
              onChange={(e) => setProposeDescription(e.target.value)}
              disabled={busy || !account}
            />
            <Input
              placeholder="Target contract (defaults to VITE_BOX_ADDRESS)"
              value={proposeTarget}
              onChange={(e) => setProposeTarget(e.target.value.trim())}
              disabled={busy || !account}
            />
            <Input
              placeholder="ETH value for call (wei, usually 0)"
              value={proposeEthValue}
              onChange={(e) => setProposeEthValue(e.target.value.trim())}
              disabled={busy || !account}
            />
            <Space wrap>
              <Typography.Text type="secondary">Payload:</Typography.Text>
              <Select
                value={proposePayload}
                onChange={(v) => setProposePayload(v)}
                disabled={busy || !account}
                options={[
                  { value: "boxStore", label: "Box.store(uint256)" },
                  { value: "custom", label: "Custom calldata" },
                ]}
                style={{ minWidth: 200 }}
              />
            </Space>
            {proposePayload === "boxStore" ? (
              <Input
                placeholder="uint256 value for store(...)"
                value={boxStoreUint}
                onChange={(e) => setBoxStoreUint(e.target.value.trim())}
                disabled={busy || !account}
              />
            ) : (
              <Input.TextArea
                placeholder="0x-prefixed calldata"
                value={customCalldata}
                onChange={(e) => setCustomCalldata(e.target.value.trim())}
                disabled={busy || !account}
                autoSize={{ minRows: 2, maxRows: 6 }}
              />
            )}
            <Button type="primary" onClick={() => submitProposal()} loading={busy} disabled={!account || !configOk}>
              Submit proposal
            </Button>
          </Space>
        </Card>

        <Card title="Governor proposals" style={{ marginTop: 24 }}>
          <Typography.Paragraph type="secondary">
            Active proposals can be voted on once voting starts (<code>voteStart</code> block/timepoint vs <code>CLOCK_MODE</code>). Results show raw token vote units (
            not decimal-formatted).
          </Typography.Paragraph>
          <Table
            loading={busy}
            rowKey={(r: ProposalRow) => r.proposalId.toString()}
            dataSource={proposals}
            columns={columns}
            pagination={{ pageSize: 5 }}
          />
        </Card>
      </Content>
    </Layout>
  );
}
