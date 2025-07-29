import React, { useEffect, useState } from "react";
import { Box, Heading, Text, Image, VStack, Spinner, Button, Link as ChakraLink } from "@chakra-ui/react";
import axios from "axios";
import AddItemModal from "./AddItemModal";
import { Link as RouterLink, useSearchParams } from "react-router-dom";
import ViewImagesModal from "./ViewImagesModal";

const API_URL = process.env.REACT_APP_API_URL || "http://127.0.0.1:8000";

export default function RecentItems() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchParams, setSearchParams] = useSearchParams();

  useEffect(() => {
    async function fetchRecent() {
      try {
        const res = await axios.get(`${API_URL}/items/recent?limit=3`);
        setItems(res.data.items);
      } catch {
        setItems([]);
      } finally {
        setLoading(false);
      }
    }
    fetchRecent();
  }, []);

  // Modal logic
  const viewImagesId = searchParams.get("viewImages");
  const selectedItem = items.find(i => String(i.item_id) === String(viewImagesId));
  const handleOpenModal = (itemId) => {
    setSearchParams({ viewImages: itemId });
  };
  const handleCloseModal = () => {
    searchParams.delete("viewImages");
    setSearchParams(searchParams);
  };

  return (
    <Box borderWidth={1} borderRadius="md" p={4} mb={4}>
      <Heading size="sm" mb={2}>Existing Items</Heading>
      <AddItemModal />
      {loading ? <Spinner /> : (
        <VStack align="start" spacing={3} pb="2">
          {items.map(item => (
            <Box
              key={item.item_id}
              display="flex"
              alignItems="center"
              width="100%"
              px={2}
              py={1}
              cursor="pointer"
              _hover={{ bg: "gray.50" }}
              onClick={() => handleOpenModal(item.item_id)}
            >
              <Image src={item.preview_image} boxSize="60px" objectFit="cover" mr={3} borderRadius="md" />
              <Box flex="1">
                <Text fontWeight="bold">{item.item_name}</Text>
                <Text fontSize="sm" color="gray.500">ID: {item.item_id}</Text>
              </Box>
              <Button size="sm" colorScheme="teal" ml={2} onClick={e => { e.stopPropagation(); handleOpenModal(item.item_id); }}>View Images</Button>
            </Box>
          ))}
          {items.length === 0 && <Text>Start by adding some items to the database</Text>}
        </VStack>
      )}
      <Button as={RouterLink} to="/items" colorScheme="teal">View All Existing Items</Button>
      <ViewImagesModal
        isOpen={!!selectedItem}
        onClose={handleCloseModal}
        item={selectedItem}
      />
    </Box>
  );
}
