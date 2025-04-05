import {readFileSync, writeFileSync } from "node:fs"

async function main() {
    const src = readFileSync("./dist/ethereum/src_ethereum_ERC20MultisigWithdrawals_sol_ERC20MultisigWithdrawals.bin").toString()

    const js = `
/**
 * @type {string}
 */
const contract = "${src}";

export default contract;
`

    writeFileSync("./dist/ethereum/index.js", js)

    const dts = `
const contract: string;

export default contract;
    `

    writeFileSync("./dist/ethereum/index.d.ts", dts)
}

main()