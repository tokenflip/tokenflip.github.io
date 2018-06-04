<template>
    <div class="history">
        <span class="tableCaption">{{ tableData.caption }}</span>
        <div class="table-container">
            <table class="table" :data="tableData">

                <tbody v-if="tableData.gridData.length > 0 && !tableData.isLoading">
                    <tr>
                        <th v-for=" column in tableData.gridColumns" class="columnName">
                            {{ column }}
                        </th>
                    </tr>
                    <tr v-for="(item) in tableData.gridData">
                        <td v-for="(key, keyIndex) in tableData.gridColumns" class="columnData">
                            <span v-if="keyIndex == 0">
                                <el-popover placement="top" trigger="click">{{ item[key] }}
                                    <el-button class="popover-button" slot="reference">
                                        {{ item[key] | truncate(10)}}
                                    </el-button>
                                </el-popover>
                            </span>
                            <span v-else>{{ item[key] }}</span>
                        </td>
                    </tr>
                </tbody>
                <span v-else-if="!tableData.isLoading" class="error ">No records found</span>
                <span v-else v-loading="true " element-loading-text="Loading... "></span>
            </table>
        </div>
    </div>
</template>

<script>
    export default {
        props: ['tableData']
    }
</script>

<style>
    .el-loading-parent--relative {
        display: flex;
        margin-top: 3vh;
        margin-bottom: 10vh;
    }

    .el-loading-text {
        font-size: 1.7rem !important;
        font-weight: bold;
    }
</style>