import React, { useEffect, useState } from "react";
import { ChakraProvider, Box, Heading, Text, Image, VStack, Spinner, Button, Modal, ModalOverlay, ModalContent, ModalHeader, ModalFooter, ModalBody, ModalCloseButton, useDisclosure, Input, FormLabel, useToast } from "@chakra-ui/react";
import axios from "axios";

import { BrowserRouter as Router, Routes, Route, Link as RouterLink } from "react-router-dom";
import AddItemModal from "./AddItemModal";
import QueryImage from "./QueryImage";
import RemoveItem from "./RemoveItem";
import ItemList from "./ItemList";
import ExistingItems from "./ExistingItems";
import RecentItems from "./RecentItems";

function App() {
  return (
    <ChakraProvider>
      <Router>
        <Box maxW="md" mx="auto" mt={10} p={6} borderWidth={1} borderRadius="lg" boxShadow="md">
          <Heading mb={4}>Part Finder</Heading>
          <Text mb={2}>Upload images, remove items, and query the database.</Text>
          <Routes>
            <Route path="/item/:itemId" element={<ItemList />} />
            <Route path="/items" element={<ExistingItems />} />
            <Route path="/" element={
              <>
                <RecentItems />
                <QueryImage />
                <Box mt={4}>
                  <Button as={RouterLink} to="/items" colorScheme="teal">View All Existing Items</Button>
                </Box>
              </>
            } />
          </Routes>
          <AddItemModal />
        </Box>
      </Router>
    </ChakraProvider>
  );
}

export default App;
