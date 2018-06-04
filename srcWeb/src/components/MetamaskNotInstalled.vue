<template>
    <el-alert v-else title="" :closable="false" type="error" center>
        <p>
            To access website features you need to have Ethereum Client
        </p>
        <p>
            Please install
            <b>MetaMask</b>,
            <b>Parity</b>,
            <b>Ethereum Mist</b> browser or any other client that supports Web3
        </p>
        <p> For the best experience use
            <a href="https://metamask.io/" target="_blank">MetaMask</a>.
        </p>
    </el-alert>
</template>

<script>

</script>

<style>
    .el-alert {
        justify-self: center;
        font-weight: bold;
        border: 1px solid
    }

    .el-alert p {
        margin-top: 5%;
        font-weight: normal;
        text-align: center;
        margin-bottom: 5%;
    }

    .el-alert p:nth-child(1) {
        font-size: 2rem;
        font-weight: bold;
    }

    a {
        color: #9549c8;
        font-weight: bold;
        text-decoration: none;
    }
</style>